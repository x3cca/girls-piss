#!/usr/bin/env python3
"""Synchronize raster artwork from the project's public Google Drive folder.

The Drive listing and downloader are kept behind small functions so the image
processing and manifest logic can be exercised without network access.  The
command-line entry point uses gdown for both operations.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath
from typing import Any, Callable, Iterable, Mapping, TextIO
from urllib.error import URLError
from urllib.parse import parse_qs, unquote, urlparse
from urllib.request import Request, urlopen

from PIL import Image, UnidentifiedImageError


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DRIVE_URL = (
    "REDACTED"
)
DEFAULT_OUTPUT_DIR = ROOT_DIR / "assets" / "art" / "drive"
DEFAULT_CACHE_DIR = ROOT_DIR / ".cache" / "drive-assets"
MANIFEST_FILENAME = "manifest.json"

SUPPORTED_EXTENSIONS = frozenset({".png", ".jpg", ".jpeg", ".webp"})
SUPPORTED_MIME_TYPES = frozenset({"image/png", "image/jpeg", "image/webp"})
_DRIVE_ID_PATTERN = re.compile(r"/(?:d|folders)/([A-Za-z0-9_-]+)")
_INVALID_FILENAME_CHARS = re.compile(r'[<>:"/\\|?*]')
_CONTROL_CHARS = re.compile(r"[\x00-\x1f\x7f]")
_WINDOWS_RESERVED_NAMES = frozenset(
    {
        "CON",
        "PRN",
        "AUX",
        "NUL",
        *(f"COM{index}" for index in range(1, 10)),
        *(f"LPT{index}" for index in range(1, 10)),
    }
)


class DriveSyncError(RuntimeError):
    """A user-facing failure while listing, downloading, or writing assets."""


@dataclass(frozen=True)
class DriveFile:
    """A file returned by gdown's folder listing."""

    id: str
    path: str
    url: str = ""
    metadata: Mapping[str, Any] = field(default_factory=dict)

    @classmethod
    def from_listing_entry(cls, entry: Mapping[str, Any]) -> "DriveFile":
        """Build a file from gdown JSON or a test fixture entry."""

        url = str(entry.get("url") or "")
        file_id = (
            entry.get("id")
            or entry.get("file_id")
            or entry.get("drive_id")
            or extract_drive_id(url)
        )
        path = entry.get("path") or entry.get("name") or entry.get("filename")
        if not file_id or not path:
            raise DriveSyncError(f"Drive listing entry is missing an id or path: {entry!r}")
        if not url:
            url = f"https://drive.google.com/uc?id={file_id}"
        return cls(
            id=str(file_id),
            path=normalise_drive_path(str(path)),
            url=url,
            metadata=dict(entry),
        )

    @property
    def name(self) -> str:
        return PurePosixPath(self.path).name

    @property
    def extension(self) -> str:
        return PurePosixPath(self.name).suffix.lower()

    def is_supported(self) -> bool:
        if self.extension in SUPPORTED_EXTENSIONS:
            return True
        mime = _metadata_value(
            self.metadata,
            "mimeType",
            "mime_type",
            "content-type",
            "content_type",
            "type",
        )
        if mime:
            return str(mime).lower().split(";", 1)[0] in SUPPORTED_MIME_TYPES
        # Drive names do not have to include their extension (the supplied
        # folder's Crosshair files are named this way). In that case let Pillow
        # validate the downloaded content; named non-raster files are skipped.
        if not self.extension:
            return True
        return False


@dataclass
class SyncResult:
    """Counts and failures produced by a check or sync run."""

    mode: str
    total: int = 0
    new: list[DriveFile] = field(default_factory=list)
    changed: list[DriveFile] = field(default_factory=list)
    unchanged: list[DriveFile] = field(default_factory=list)
    removed: list[dict[str, Any]] = field(default_factory=list)
    unsupported: list[DriveFile] = field(default_factory=list)
    downloaded: list[DriveFile] = field(default_factory=list)
    written: list[DriveFile] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors

    @property
    def exit_code(self) -> int:
        return 0 if self.ok else 1


def extract_drive_id(url: str) -> str | None:
    """Extract a Drive file/folder ID from the URL forms gdown accepts."""

    if not url:
        return None
    query_id = parse_qs(urlparse(url).query).get("id")
    if query_id and query_id[0]:
        return query_id[0]
    match = _DRIVE_ID_PATTERN.search(urlparse(url).path)
    return match.group(1) if match else None


def normalise_drive_path(path: str) -> str:
    """Use stable POSIX separators for paths returned by gdown."""

    decoded = unquote(path).replace("\\", "/")
    return "/".join(part for part in decoded.split("/") if part not in ("", "."))


def sanitize_filename(value: str, *, fallback: str = "unnamed") -> str:
    """Make one Drive path component safe on common host filesystems."""

    value = unicodedata.normalize("NFKC", str(value))
    value = _CONTROL_CHARS.sub("_", value)
    value = _INVALID_FILENAME_CHARS.sub("_", value)
    value = value.strip().strip(" .")
    if not value or value in {".", ".."}:
        value = fallback
    if value.upper() in _WINDOWS_RESERVED_NAMES:
        value = f"_{value}"
    # Keep room for the collision suffix and a normal filesystem limit.
    return value[:180]


def _safe_relative_path(path: str) -> PurePosixPath:
    parts: list[str] = []
    for index, component in enumerate(normalise_drive_path(path).split("/")):
        if component in {".", ".."}:
            component = f"_{component}"
        safe = sanitize_filename(component, fallback="unnamed")
        if index == len(normalise_drive_path(path).split("/")) - 1:
            source_suffix = PurePosixPath(component).suffix
            if source_suffix:
                stem = component[: -len(source_suffix)]
                safe = f"{sanitize_filename(stem, fallback='unnamed')}.png"
            else:
                safe = f"{safe}.png"
        parts.append(safe)
    if not parts:
        return PurePosixPath("unnamed.png")
    return PurePosixPath(*parts)


def output_paths(files: Iterable[DriveFile]) -> dict[str, PurePosixPath]:
    """Assign deterministic, collision-free output paths to supported files."""

    supported = sorted(
        (file for file in files if file.is_supported()),
        key=lambda file: (str(_safe_relative_path(file.path)), file.id),
    )
    bases: dict[str, list[DriveFile]] = defaultdict(list)
    for file in supported:
        bases[str(_safe_relative_path(file.path))].append(file)

    assignments: dict[str, PurePosixPath] = {}
    used: set[str] = set()
    for base_name in sorted(bases):
        group = sorted(bases[base_name], key=lambda file: file.id)
        for index, file in enumerate(group):
            base = PurePosixPath(base_name)
            if index == 0:
                candidate = base
            else:
                candidate = _with_drive_id_suffix(base, file.id)
            candidate = _avoid_path_collision(candidate, used, file.id)
            assignments[file.id] = candidate
            used.add(str(candidate))
    return assignments


def _with_drive_id_suffix(path: PurePosixPath, drive_id: str, ordinal: int | None = None) -> PurePosixPath:
    suffix = sanitize_filename(drive_id, fallback="drive-id")
    if ordinal is not None:
        suffix = f"{suffix}-{ordinal}"
    return path.with_name(f"{path.stem}__{suffix}{path.suffix}")


def _avoid_path_collision(path: PurePosixPath, used: set[str], drive_id: str) -> PurePosixPath:
    if str(path) not in used:
        return path
    ordinal = 2
    while True:
        candidate = _with_drive_id_suffix(path, drive_id, ordinal)
        if str(candidate) not in used:
            return candidate
        ordinal += 1


def crop_transparent_border(image: Image.Image) -> Image.Image:
    """Trim only fully transparent outer pixels, retaining RGB values and white."""

    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        # Pillow cannot represent a zero-sized image. A one-pixel transparent
        # image is the lossless, valid representation of an entirely empty one.
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    return rgba.crop(bbox)


def convert_image_to_png(source: Path, destination: Path) -> None:
    """Decode, crop, and atomically write one image as a lossless PNG."""

    try:
        with Image.open(source) as image:
            image.load()
            converted = crop_transparent_border(image)
            try:
                _atomic_save_png(converted, destination)
            finally:
                converted.close()
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError) as error:
        raise DriveSyncError(f"could not decode {source.name}: {error}") from error


def _atomic_save_png(image: Image.Image, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            dir=destination.parent,
            prefix=f".{destination.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            image.save(temporary, format="PNG", optimize=False)
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_path, destination)
        _fsync_directory(destination.parent)
    except OSError as error:
        raise DriveSyncError(f"could not write {destination}: {error}") from error
    finally:
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink(missing_ok=True)


def _fsync_directory(directory: Path) -> None:
    try:
        descriptor = os.open(directory, os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(descriptor)
    except OSError:
        pass
    finally:
        os.close(descriptor)


def list_drive_files(source: str) -> list[DriveFile]:
    """List a public folder through gdown's non-downloading folder API."""
    try:
        import gdown
    except ImportError as error:
        raise DriveSyncError("gdown is not installed; install requirements.txt first") from error
    try:
        source_id = extract_drive_id(source)
        if source_id:
            listed = gdown.download_folder(
                id=source_id,
                quiet=True,
                remaining_ok=True,
                skip_download=True,
            )
        else:
            listed = gdown.download_folder(
                url=source,
                quiet=True,
                remaining_ok=True,
                skip_download=True,
            )
    except Exception as error:  # gdown exposes several listing/transport exception types.
        raise DriveSyncError(f"gdown could not list the folder: {error}") from error
    if listed is None:
        raise DriveSyncError("gdown could not list the folder")
    entries: list[Mapping[str, Any]] = []
    for item in listed:
        if isinstance(item, Mapping):
            entries.append(item)
            continue
        file_id = getattr(item, "id", None)
        path = getattr(item, "path", None)
        if not file_id or not path:
            raise DriveSyncError(f"gdown returned an incomplete file entry: {item!r}")
        entries.append(
            {
                "id": str(file_id),
                "path": str(path),
                "url": f"https://drive.google.com/uc?id={file_id}",
            }
        )
    return _normalise_listing(_probe_listing_metadata(entries))


def _probe_listing_metadata(entries: Iterable[Mapping[str, Any]]) -> list[Mapping[str, Any]]:
    """Add cheap HTTP metadata when Drive's gdown object omits file revisions."""

    enriched: list[Mapping[str, Any]] = []
    for entry in entries:
        url = str(entry.get("url") or "")
        if not url:
            enriched.append(entry)
            continue
        metadata = dict(entry)
        try:
            request = Request(url, method="HEAD", headers={"User-Agent": "girl-pisser-drive-sync"})
            with urlopen(request, timeout=10) as response:
                for key in ("Content-Type", "Content-Length", "Last-Modified", "ETag"):
                    value = response.headers.get(key)
                    if value:
                        metadata[key] = value
        except (OSError, URLError):
            # HEAD is an optimization. A public Drive listing is still useful
            # when a proxy or server does not support it.
            pass
        enriched.append(metadata)
    return enriched


def _normalise_listing(entries: Iterable[Mapping[str, Any] | DriveFile]) -> list[DriveFile]:
    files: list[DriveFile] = []
    seen_ids: set[str] = set()
    for entry in entries:
        file = entry if isinstance(entry, DriveFile) else DriveFile.from_listing_entry(entry)
        if file.id in seen_ids:
            raise DriveSyncError(f"Drive listing contains duplicate file ID {file.id}")
        seen_ids.add(file.id)
        files.append(file)
    return sorted(files, key=lambda file: (file.path.casefold(), file.id))


def download_drive_file(file: DriveFile, destination: Path) -> None:
    """Download one public Drive file using gdown's Python API."""

    try:
        import gdown
    except ImportError as error:
        raise DriveSyncError("gdown is not installed; install requirements.txt first") from error
    try:
        result = gdown.download(id=file.id, output=str(destination), quiet=True)
    except Exception as error:  # gdown exposes several transport exception types.
        raise DriveSyncError(f"download failed for {file.path}: {error}") from error
    if result is False or result is None or not destination.is_file():
        raise DriveSyncError(f"download failed for {file.path}: gdown produced no file")


def load_manifest(cache_dir: Path) -> dict[str, Any]:
    path = cache_dir / MANIFEST_FILENAME
    if not path.exists():
        return {"version": 1, "files": {}}
    try:
        with path.open("r", encoding="utf-8") as manifest_file:
            manifest = json.load(manifest_file)
    except (OSError, json.JSONDecodeError) as error:
        raise DriveSyncError(f"could not read {path}: {error}") from error
    if not isinstance(manifest, dict) or not isinstance(manifest.get("files", {}), dict):
        raise DriveSyncError(f"manifest {path} has an unsupported format")
    return manifest


def write_manifest(cache_dir: Path, manifest: Mapping[str, Any]) -> None:
    """Write the manifest atomically, just like processed output assets."""

    cache_dir.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=cache_dir,
            prefix=".manifest.",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            json.dump(manifest, temporary, indent=2, ensure_ascii=False, sort_keys=True)
            temporary.write("\n")
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_path, cache_dir / MANIFEST_FILENAME)
        _fsync_directory(cache_dir)
    except OSError as error:
        raise DriveSyncError(f"could not write {cache_dir / MANIFEST_FILENAME}: {error}") from error
    finally:
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink(missing_ok=True)


def run_sync(
    source: str = DEFAULT_DRIVE_URL,
    output_dir: Path = DEFAULT_OUTPUT_DIR,
    cache_dir: Path = DEFAULT_CACHE_DIR,
    *,
    check: bool = False,
    list_files_fn: Callable[[str], list[DriveFile]] | None = None,
    download_file_fn: Callable[[DriveFile, Path], None] | None = None,
    stream: TextIO | None = None,
) -> SyncResult:
    """Run a check or sync, optionally with offline test doubles."""

    output_dir = Path(output_dir)
    cache_dir = Path(cache_dir)
    result = SyncResult(mode="check" if check else "sync")
    stream = stream or sys.stdout
    list_files_fn = list_files_fn or list_drive_files
    download_file_fn = download_file_fn or download_drive_file

    try:
        current_files = _normalise_listing(list_files_fn(source))
        old_manifest = load_manifest(cache_dir)
    except Exception as error:
        result.errors.append(str(error))
        print(f"ERROR: {error}", file=stream)
        return result

    if old_manifest.get("source") not in (None, source):
        print("Source folder changed; ignoring the previous folder manifest.", file=stream)
        old_manifest = {"version": 1, "files": {}}
    old_files: dict[str, Mapping[str, Any]] = old_manifest.get("files", {})
    result.total = len(current_files)
    current_ids = {file.id for file in current_files}
    result.removed = [
        dict(entry)
        for file_id, entry in sorted(old_files.items())
        if file_id not in current_ids and not entry.get("removed", False)
    ]
    assignments = output_paths(current_files)
    work: list[tuple[DriveFile, PurePosixPath, str]] = []

    for file in current_files:
        if not file.is_supported():
            result.unsupported.append(file)
            continue
        output_relative = assignments[file.id]
        fingerprint = source_fingerprint(file)
        prior = old_files.get(file.id)
        destination = output_dir.joinpath(*output_relative.parts)
        unchanged = bool(
            prior
            and prior.get("synced")
            and prior.get("fingerprint") == fingerprint
            and prior.get("output") == str(output_relative)
            and destination.is_file()
        )
        if unchanged:
            result.unchanged.append(file)
            continue
        if prior:
            result.changed.append(file)
            work.append((file, output_relative, "changed"))
        else:
            result.new.append(file)
            work.append((file, output_relative, "new"))

    _print_summary(result, stream)
    if check:
        _print_details(result, stream)
        return result

    manifest_files: dict[str, dict[str, Any]] = {}
    for file in current_files:
        if not file.is_supported():
            manifest_files[file.id] = _manifest_entry(
                file,
                source_fingerprint(file),
                supported=False,
                output=None,
                synced=False,
            )
    for file in result.unchanged:
        prior = old_files[file.id]
        manifest_files[file.id] = dict(prior)
        manifest_files[file.id]["removed"] = False
    for file in result.new + result.changed:
        relative = assignments[file.id]
        manifest_files[file.id] = _manifest_entry(
            file,
            source_fingerprint(file),
            supported=True,
            output=relative,
            synced=False,
        )

    downloads_dir = cache_dir / "downloads"
    for file, relative, change_type in work:
        raw_path = downloads_dir / f"{sanitize_filename(file.id, fallback='drive-id')}.source"
        part_path = downloads_dir / f".{sanitize_filename(file.id, fallback='drive-id')}.part"
        try:
            downloads_dir.mkdir(parents=True, exist_ok=True)
            part_path.unlink(missing_ok=True)
            download_file_fn(file, part_path)
            if not part_path.is_file():
                raise DriveSyncError(f"download failed for {file.path}: no temporary file was produced")
            os.replace(part_path, raw_path)
            result.downloaded.append(file)
            convert_image_to_png(raw_path, output_dir.joinpath(*relative.parts))
            manifest_files[file.id] = _manifest_entry(
                file,
                source_fingerprint(file),
                supported=True,
                output=relative,
                synced=True,
                sha256=_sha256(output_dir.joinpath(*relative.parts)),
            )
            result.written.append(file)
            print(f"{change_type}: {file.path} -> {relative}", file=stream)
        except Exception as error:
            message = f"{file.path}: {error}"
            result.errors.append(message)
            manifest_files[file.id]["error"] = str(error)
            print(f"ERROR: {message}", file=stream)
        finally:
            part_path.unlink(missing_ok=True)

    for file_id, entry in old_files.items():
        if file_id not in current_ids and not entry.get("removed", False):
            removed_entry = dict(entry)
            removed_entry["removed"] = True
            manifest_files[file_id] = removed_entry

    manifest = {
        "version": 1,
        "source": source,
        "files": {file_id: manifest_files[file_id] for file_id in sorted(manifest_files)},
    }
    try:
        write_manifest(cache_dir, manifest)
    except DriveSyncError as error:
        result.errors.append(str(error))
        print(f"ERROR: {error}", file=stream)
    _print_details(result, stream)
    return result


def sync_assets(*args: Any, **kwargs: Any) -> SyncResult:
    """Compatibility-friendly alias for callers that prefer an imperative name."""

    return run_sync(*args, **kwargs)


def source_fingerprint(file: DriveFile) -> dict[str, Any]:
    """Return stable listing metadata used to identify a changed Drive file."""

    remote: dict[str, Any] = {}
    for key, value in file.metadata.items():
        lowered = str(key).lower().replace("_", "").replace("-", "")
        if (
            lowered
            in {
                "md5checksum",
                "sha256checksum",
                "checksum",
                "size",
                "contentlength",
                "contenttype",
                "version",
                "revision",
                "revisionid",
                "etag",
            }
            or "modified" in lowered
            or lowered.endswith("hash")
        ):
            remote[str(key)] = value
    return {"path": file.path, "remote": remote}


def _manifest_entry(
    file: DriveFile,
    fingerprint: Mapping[str, Any],
    *,
    supported: bool,
    output: PurePosixPath | None,
    synced: bool,
    sha256: str | None = None,
) -> dict[str, Any]:
    entry: dict[str, Any] = {
        "id": file.id,
        "path": file.path,
        "url": file.url,
        "fingerprint": dict(fingerprint),
        "supported": supported,
        "synced": synced,
        "removed": False,
    }
    if output is not None:
        entry["output"] = str(output)
    if sha256 is not None:
        entry["sha256"] = sha256
    return entry


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as asset:
        for chunk in iter(lambda: asset.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _metadata_value(metadata: Mapping[str, Any], *keys: str) -> Any:
    wanted = {key.lower().replace("_", "").replace("-", "") for key in keys}
    for key in keys:
        if key in metadata:
            return metadata[key]
    for key, value in metadata.items():
        normalised = str(key).lower().replace("_", "").replace("-", "")
        if normalised in wanted:
            return value
    return None


def _print_summary(result: SyncResult, stream: TextIO) -> None:
    print(
        f"{result.mode}: {result.total} Drive file(s); "
        f"new={len(result.new)}, changed={len(result.changed)}, "
        f"unchanged={len(result.unchanged)}, removed={len(result.removed)}, "
        f"unsupported={len(result.unsupported)}",
        file=stream,
    )


def _print_details(result: SyncResult, stream: TextIO) -> None:
    for entry in result.removed:
        print(f"removed (kept locally): {entry.get('path', entry.get('id', 'unknown'))}", file=stream)
    for file in result.unsupported:
        print(f"unsupported (skipped): {file.path}", file=stream)
    if not result.errors and result.mode == "sync":
        print(f"sync complete: downloaded={len(result.downloaded)}, written={len(result.written)}", file=stream)


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="list changes without downloading or writing")
    mode.add_argument("--sync", action="store_true", help="download and process new or changed assets")
    parser.add_argument(
        "--source",
        default=os.environ.get("DRIVE_ASSETS_URL", DEFAULT_DRIVE_URL),
        help="public Drive folder URL (or set DRIVE_ASSETS_URL)",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT_DIR, help="PNG output directory")
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE_DIR, help="ignored working cache")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    result = run_sync(
        source=args.source,
        output_dir=args.output,
        cache_dir=args.cache_dir,
        check=args.check,
    )
    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
