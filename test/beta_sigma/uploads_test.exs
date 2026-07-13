defmodule BetaSigma.UploadsTest do
  use ExUnit.Case, async: false

  alias BetaSigma.Uploads

  setup do
    uploads_dir = Path.expand("tmp/test_uploads/#{System.unique_integer([:positive])}", __DIR__)
    Application.put_env(:beta_sigma, :uploads, directory: uploads_dir, base_url_path: "/uploads")
    File.mkdir_p!(uploads_dir)

    on_exit(fn ->
      File.rm_rf!(uploads_dir)
      Application.delete_env(:beta_sigma, :uploads)
    end)

    {:ok, uploads_dir: uploads_dir}
  end

  describe "local_path_for_url/1" do
    test "refuses path traversal and absolute-relative upload URLs", %{uploads_dir: uploads_dir} do
      assert {:error, :not_local} = Uploads.local_path_for_url("/uploads/../etc/passwd")
      assert {:error, :not_local} = Uploads.local_path_for_url("/uploads/..//etc/passwd")

      assert {:error, :not_local} =
               Uploads.local_path_for_url("/uploads/../../#{Path.basename(uploads_dir)}")

      assert {:error, :not_local} = Uploads.local_path_for_url("/uploads//etc/passwd")

      outside_file = Path.expand(Path.join(uploads_dir, "../escaped.txt"))
      File.write!(outside_file, "keep")
      assert File.exists?(outside_file)

      assert :ok = Uploads.delete_local_upload("/uploads/../escaped.txt")
      assert File.exists?(outside_file)
    end

    test "rejects symlink escapes under the uploads directory", %{uploads_dir: uploads_dir} do
      outside_file = Path.expand(Path.join(uploads_dir, "../escaped.txt"))
      File.write!(outside_file, "keep")
      assert File.exists?(outside_file)

      symlink = Path.join(uploads_dir, "user.txt")
      assert :ok = :file.make_symlink(to_charlist(outside_file), to_charlist(symlink))

      assert {:error, :not_local} = Uploads.local_path_for_url("/uploads/user.txt")
      assert :ok = Uploads.delete_local_upload("/uploads/user.txt")
      assert File.exists?(outside_file)
      assert File.exists?(symlink)
    end

    test "rejects non-existing relative paths under uploads directory" do
      assert {:error, :not_local} = Uploads.local_path_for_url("/uploads/avatars/missing.png")
    end

    test "resolves safe upload URLs inside configured directory", %{uploads_dir: uploads_dir} do
      nested = Path.join([uploads_dir, "avatars", "user.png"])
      File.mkdir_p!(Path.dirname(nested))
      File.write!(nested, "data")

      assert {:ok, resolved} = Uploads.local_path_for_url("/uploads/avatars/user.png")
      assert resolved == nested
      assert File.exists?(resolved)
    end
  end

  describe "delete_local_upload/1" do
    test "deletes files only inside uploads directory", %{uploads_dir: uploads_dir} do
      file_path = Path.join([uploads_dir, "avatars", "remove.png"])
      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, "avatar")

      assert :ok = Uploads.delete_local_upload("/uploads/avatars/remove.png")
      refute File.exists?(file_path)
    end

    test "ignores File.rm failures and still returns :ok", %{uploads_dir: uploads_dir} do
      file_path = Path.join([uploads_dir, "avatars", "remove.png"])
      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, "avatar")

      dir_path = Path.dirname(file_path)
      File.chmod!(dir_path, 0o500)

      try do
        assert :ok = Uploads.delete_local_upload("/uploads/avatars/remove.png")
        assert File.exists?(file_path)
      after
        File.chmod!(dir_path, 0o700)
      end
    end

    test "does not delete symlink targets when upload path points to a symlink", %{
      uploads_dir: uploads_dir
    } do
      outside_file = Path.expand(Path.join(uploads_dir, "../escaped.txt"))
      File.write!(outside_file, "keep")

      symlink = Path.join([uploads_dir, "avatars", "link.png"])
      File.mkdir_p!(Path.dirname(symlink))
      assert :ok = :file.make_symlink(to_charlist(outside_file), to_charlist(symlink))

      assert :ok = Uploads.delete_local_upload("/uploads/avatars/link.png")
      assert File.exists?(outside_file)
      assert File.exists?(symlink)
    end

    test "ignores external URLs and non-local upload paths" do
      assert :ok = Uploads.delete_local_upload("https://example.com/uploads/avatars/remove.png")
      assert :ok = Uploads.delete_local_upload("http://localhost/uploads/avatars/remove.png")
      assert :ok = Uploads.delete_local_upload("/files/avatars/remove.png")
      assert :ok = Uploads.delete_local_upload("../uploads/avatars/remove.png")
    end
  end

  describe "validate_avatar_upload/2" do
    test "accepts valid PNG images" do
      png =
        <<
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x00,
          0x00,
          0x0D,
          "IHDR",
          0x00,
          0x00,
          0x00,
          0xC8,
          0x00,
          0x00,
          0x00,
          0xC8,
          0x08,
          0x06,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00
        >>

      path = Path.join(Path.expand("tmp", __DIR__), "valid.png")
      File.write!(path, png)

      assert {:ok, %{content_type: "image/png", width: 200, height: 200}} =
               Uploads.validate_avatar_upload(path)

      File.rm_rf!(path)
    end

    test "accepts valid WebP images" do
      webp =
        <<
          "RIFF",
          0x1A,
          0x00,
          0x00,
          0x00,
          "WEBP",
          "VP8X",
          0x0A,
          0x00,
          0x00,
          0x00,
          0x00,
          199::little-24,
          199::little-24
        >>

      path = Path.join(Path.expand("tmp", __DIR__), "valid.webp")
      File.write!(path, webp)

      assert {:ok, %{content_type: "image/webp", width: 200, height: 200}} =
               Uploads.validate_avatar_upload(path)

      File.rm_rf!(path)
    end

    test "rejects too small PNG images" do
      small_png =
        <<
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x00,
          0x00,
          0x0D,
          "IHDR",
          0x00,
          0x00,
          0x00,
          0x40,
          0x00,
          0x00,
          0x00,
          0x40,
          0x08,
          0x06,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00,
          0x00
        >>

      path = Path.join(Path.expand("tmp", __DIR__), "small.png")
      File.write!(path, small_png)

      assert {:error, :image_too_small} = Uploads.validate_avatar_upload(path)

      File.rm_rf!(path)
    end

    test "returns an error instead of crashing for malformed jpeg segment lengths" do
      malformed_jpeg = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x01>>
      path = Path.join(Path.expand("tmp", __DIR__), "malformed.jpeg")
      File.write!(path, malformed_jpeg)

      assert {:error, :invalid_image_dimensions} = Uploads.validate_avatar_upload(path)

      File.rm_rf!(path)
    end

    test "returns an error for truncated jpeg segment data" do
      truncated_jpeg = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, "JFIF\0", 0x01>>
      path = Path.join(Path.expand("tmp", __DIR__), "truncated.jpeg")
      File.write!(path, truncated_jpeg)

      assert {:error, :invalid_image_dimensions} = Uploads.validate_avatar_upload(path)

      File.rm_rf!(path)
    end

    test "returns an error for malformed jpeg segment lengths" do
      bad_segment_length = <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x01, "JFIF\0">>
      path = Path.join(Path.expand("tmp", __DIR__), "bad_segment_length.jpeg")
      File.write!(path, bad_segment_length)

      assert {:error, :invalid_image_dimensions} = Uploads.validate_avatar_upload(path)

      File.rm_rf!(path)
    end

    test "returns an error for invalid jpeg segments with insufficient data" do
      short_segment = <<0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x10, "JFIF\0">>
      path = Path.join(Path.expand("tmp", __DIR__), "short_segment.jpeg")
      File.write!(path, short_segment)

      assert {:error, :invalid_image_dimensions} = Uploads.validate_avatar_upload(path)

      File.rm_rf!(path)
    end

    test "does not detect JPEG when signature appears later in the file" do
      body = "notjpeg" <> <<0xFF, 0xD8, 0xFF>> <> "moredata"
      path = Path.join(Path.expand("tmp", __DIR__), "embedded_signature.bin")
      File.write!(path, body)

      assert {:error, :invalid_image_type} = Uploads.validate_avatar_upload(path)

      File.rm_rf!(path)
    end
  end
end
