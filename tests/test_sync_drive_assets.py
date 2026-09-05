import io
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from tools.sync_drive_assets import DriveFile
from tools.sync_drive_assets import convert_image_to_png
from tools.sync_drive_assets import crop_transparent_border
from tools.sync_drive_assets import output_paths
from tools.sync_drive_assets import run_sync


def image_bytes(format_name, size=(6, 5), color=(40, 80, 120, 255)):
    image = Image.new("RGBA", size, color)
    if format_name == "JPEG":
        image = image.convert("RGB")
    buffer = io.BytesIO()
    image.save(buffer, format=format_name)
    return buffer.getvalue()


class DriveAssetImageTests(unittest.TestCase):
    def test_crops_only_fully_transparent_border(self):
        image = Image.new("RGBA", (10, 8), (255, 0, 0, 0))
        for y in range(1, 7):
            for x in range(2, 8):
                image.putpixel((x, y), (255, 0, 0, 255))

        cropped = crop_transparent_border(image)

        self.assertEqual(cropped.size, (6, 6))
        self.assertEqual(cropped.getpixel((0, 0)), (255, 0, 0, 255))

    def test_opaque_white_border_remains_intact(self):
        image = Image.new("RGBA", (9, 7), (255, 255, 255, 255))
        image.putpixel((4, 3), (30, 50, 70, 255))

        cropped = crop_transparent_border(image)

        self.assertEqual(cropped.size, image.size)
        self.assertEqual(cropped.getpixel((0, 0)), (255, 255, 255, 255))

    def test_png_jpeg_and_webp_are_written_as_png(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for extension, format_name in (("png", "PNG"), ("jpg", "JPEG"), ("webp", "WEBP")):
                source = root / f"source.{extension}"
                destination = root / f"result_{extension}.png"
                source.write_bytes(image_bytes(format_name))

                convert_image_to_png(source, destination)

                with Image.open(destination) as output:
                    self.assertEqual(output.format, "PNG")
                    self.assertEqual(output.size, (6, 5))

    def test_fully_transparent_image_becomes_valid_one_pixel_png(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "empty.png"
            destination = root / "empty-result.png"
            Image.new("RGBA", (20, 30), (255, 255, 255, 0)).save(source)

            convert_image_to_png(source, destination)

            with Image.open(destination) as output:
                self.assertEqual(output.size, (1, 1))
                self.assertEqual(output.getpixel((0, 0)), (0, 0, 0, 0))


class DriveAssetSyncTests(unittest.TestCase):
    def test_nested_paths_and_sanitized_collisions_get_stable_drive_suffix(self):
        files = [
            DriveFile("drive-b", "Characters/Hero*.jpg"),
            DriveFile("drive-a", "Characters/Hero?.png"),
        ]

        paths = output_paths(files)

        self.assertEqual(str(paths["drive-a"]), "Characters/Hero_.png")
        self.assertIn("Characters/Hero___drive-b.png", str(paths["drive-b"]))
        self.assertEqual(paths, output_paths(list(reversed(files))))

    def test_new_changed_unchanged_and_removed_files(self):
        listing = [
            {"id": "one", "path": "nested/one.png", "modifiedTime": "1"},
            {"id": "two", "path": "two.webp", "modifiedTime": "1"},
        ]
        contents = {
            "one": image_bytes("PNG", (5, 5), (255, 0, 0, 255)),
            "two": image_bytes("WEBP", (4, 4), (0, 255, 0, 255)),
        }
        calls = []

        def list_files(_source):
            return list(listing)

        def download(file, destination):
            calls.append(file.id)
            destination.write_bytes(contents[file.id])

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / "assets"
            cache = root / "cache"

            first = run_sync("folder", output, cache, list_files_fn=list_files, download_file_fn=download)
            self.assertEqual(len(first.new), 2)
            self.assertEqual(calls, ["one", "two"])
            self.assertTrue((output / "nested/one.png").is_file())

            calls.clear()
            second = run_sync("folder", output, cache, list_files_fn=list_files, download_file_fn=download)
            self.assertEqual(len(second.unchanged), 2)
            self.assertEqual(calls, [])

            listing[0] = {"id": "one", "path": "nested/one.png", "modifiedTime": "2"}
            contents["one"] = image_bytes("PNG", (7, 3), (0, 0, 255, 255))
            third = run_sync("folder", output, cache, list_files_fn=list_files, download_file_fn=download)
            self.assertEqual([file.id for file in third.changed], ["one"])
            self.assertEqual(calls, ["one"])
            with Image.open(output / "nested/one.png") as changed:
                self.assertEqual(changed.size, (7, 3))

            listing.pop()
            fourth = run_sync("folder", output, cache, list_files_fn=list_files, download_file_fn=download)
            self.assertEqual([entry["id"] for entry in fourth.removed], ["two"])
            self.assertTrue((output / "two.png").is_file())

            manifest = json.loads((cache / "manifest.json").read_text(encoding="utf-8"))
            self.assertTrue(manifest["files"]["two"]["removed"])

    def test_unsupported_files_are_reported_without_failure(self):
        listing = [{"id": "document", "path": "notes.pdf"}]
        with tempfile.TemporaryDirectory() as temporary:
            result = run_sync(
                "folder",
                Path(temporary) / "assets",
                Path(temporary) / "cache",
                list_files_fn=lambda _source: listing,
                download_file_fn=lambda _file, _destination: self.fail("must not download PDF"),
            )

        self.assertTrue(result.ok)
        self.assertEqual([file.id for file in result.unsupported], ["document"])

    def test_download_and_decode_failures_return_failure_status(self):
        listing = [
            {"id": "download-error", "path": "download.png"},
            {"id": "decode-error", "path": "decode.png"},
        ]

        def download(_file, destination):
            if _file.id == "download-error":
                raise OSError("network unavailable")
            destination.write_bytes(b"not an image")

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            result = run_sync(
                "folder",
                root / "assets",
                root / "cache",
                list_files_fn=lambda _source: listing,
                download_file_fn=download,
            )
            self.assertFalse(result.ok)
            self.assertEqual(result.exit_code, 1)
            self.assertEqual(len(result.errors), 2)
            self.assertFalse((root / "assets/download.png").exists())
            self.assertFalse((root / "assets/decode.png").exists())
            self.assertFalse(list((root / "assets").glob("*.tmp")))


if __name__ == "__main__":
    unittest.main()
