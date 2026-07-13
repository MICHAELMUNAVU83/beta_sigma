defmodule BetaSigma.Uploads do
  @moduledoc false

  @allowed_avatar_content_types ["image/jpeg", "image/png", "image/webp"]
  @avatar_min_dimension 128

  def directory do
    config()[:directory]
  end

  def base_url_path do
    config()[:base_url_path]
  end

  def ensure_directories! do
    directory()
    |> File.mkdir_p!()
  end

  def persist_upload!(scope, %{path: temp_path}, client_name) when is_binary(scope) do
    scope_directory = Path.join(directory(), scope)
    File.mkdir_p!(scope_directory)

    extension = Path.extname(client_name)
    filename = build_uuid_filename(extension)
    destination = Path.join(scope_directory, filename)

    File.cp!(temp_path, destination)

    Path.join(base_url_path(), Path.join(scope, filename))
  end

  def persist_binary!(scope, binary, extension, basename \\ "ai")
      when is_binary(scope) and is_binary(binary) and is_binary(extension) and is_binary(basename) do
    scope_directory = Path.join(directory(), scope)
    File.mkdir_p!(scope_directory)

    extension = extension |> String.trim() |> String.trim_leading(".")
    extension = if extension == "", do: "bin", else: extension

    basename = sanitize_basename(basename)
    filename = build_uuid_filename(extension, basename)
    destination = Path.join(scope_directory, filename)

    File.write!(destination, binary)

    Path.join(base_url_path(), Path.join(scope, filename))
  end

  def validate_avatar_upload(path, client_type \\ nil) when is_binary(path) do
    with {:ok, detected_type} <- detect_image_content_type(path),
         :ok <- validate_avatar_content_type(client_type, detected_type),
         {:ok, width, height} <- image_dimensions(path),
         :ok <- validate_avatar_dimensions(width, height) do
      {:ok, %{content_type: detected_type, width: width, height: height}}
    end
  end

  @doc """
  Resolves a public upload URL (e.g. `/uploads/aptitude_screenshots/foo.jpg`) to its
  absolute path on disk. Returns `{:error, :not_local}` when the URL does not live
  under the configured base path.
  """
  def delete_local_upload(url) when is_binary(url) do
    with {:ok, path} <- local_path_for_url(url),
         true <- File.exists?(path),
         {:ok, %File.Stat{type: :regular}} <- File.lstat(path) do
      case File.rm(path) do
        :ok -> :ok
        {:error, _reason} -> :ok
      end
    else
      _ -> :ok
    end
  end

  def delete_local_upload(_url), do: :ok

  def local_path_for_url(url) when is_binary(url) do
    base = base_url_path() |> String.trim_trailing("/")

    cond do
      String.starts_with?(url, base <> "/") ->
        url
        |> String.trim_leading(base <> "/")
        |> local_upload_path_from_relative()

      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
        {:error, :not_local}

      true ->
        {:error, :not_local}
    end
  end

  defp local_upload_path_from_relative(<<"/", _rest::binary>>), do: {:error, :not_local}

  defp local_upload_path_from_relative(relative) do
    resolved = Path.expand(Path.join(directory(), relative))
    base_directory = Path.expand(directory())

    if path_within_directory?(resolved, base_directory) and
         not path_contains_symlink?(base_directory, resolved) do
      {:ok, resolved}
    else
      {:error, :not_local}
    end
  end

  defp path_contains_symlink?(base_directory, resolved) do
    relative = String.trim_leading(resolved, base_directory)
    segments = String.split(relative, "/", trim: true)

    Enum.reduce_while(segments, base_directory, fn segment, current ->
      current = Path.join(current, segment)

      case File.lstat(current) do
        {:ok, %File.Stat{type: :symlink}} -> {:halt, true}
        {:ok, _stat} -> {:cont, current}
        {:error, _} -> {:halt, true}
      end
    end)
    |> case do
      true -> true
      _ -> false
    end
  end

  defp path_within_directory?(resolved, base_directory) do
    resolved == base_directory or String.starts_with?(resolved, base_directory <> "/")
  end

  defp config do
    Application.fetch_env!(:beta_sigma, :uploads)
  end

  defp detect_image_content_type(path) do
    case File.read(path) do
      {:ok, binary} ->
        case binary do
          <<0xFF, 0xD8, 0xFF, _rest::binary>> -> {:ok, "image/jpeg"}
          _ -> detect_non_jpeg_content_type(binary)
        end

      {:error, reason} ->
        {:error, {:read_failed, reason}}
    end
  end

  defp detect_non_jpeg_content_type(
         <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>
       ),
       do: {:ok, "image/png"}

  defp detect_non_jpeg_content_type(<<"RIFF", _size::binary-size(4), "WEBP", _::binary>>),
    do: {:ok, "image/webp"}

  defp detect_non_jpeg_content_type(_binary), do: {:error, :invalid_image_type}

  defp validate_avatar_content_type(nil, detected_type)
       when detected_type in @allowed_avatar_content_types,
       do: :ok

  defp validate_avatar_content_type(client_type, detected_type)
       when is_binary(client_type) and detected_type in @allowed_avatar_content_types do
    normalized_client_type =
      client_type
      |> String.downcase()
      |> String.trim()
      |> String.split(";", parts: 2)
      |> List.first()

    if normalized_client_type in @allowed_avatar_content_types do
      :ok
    else
      {:error, :invalid_image_type}
    end
  end

  defp validate_avatar_content_type(_client_type, detected_type)
       when detected_type in @allowed_avatar_content_types,
       do: :ok

  defp validate_avatar_content_type(_client_type, _detected_type),
    do: {:error, :invalid_image_type}

  defp image_dimensions(path) do
    case File.read(path) do
      {:ok, binary} ->
        case png_dimensions(binary) || jpeg_dimensions(binary) || webp_dimensions(binary) do
          nil -> {:error, :invalid_image_dimensions}
          dimensions -> dimensions
        end

      {:error, reason} ->
        {:error, {:read_failed, reason}}
    end
  end

  defp png_dimensions(
         <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _len::32, "IHDR", width::32,
           height::32, _::binary>>
       ),
       do: {:ok, width, height}

  defp png_dimensions(_), do: nil

  defp jpeg_dimensions(<<0xFF, 0xD8, rest::binary>>), do: scan_jpeg_segments(rest)
  defp jpeg_dimensions(_), do: nil

  defp scan_jpeg_segments(<<0xFF, marker, _segment_length::16, data::binary>>)
       when marker in [
              0xC0,
              0xC1,
              0xC2,
              0xC3,
              0xC5,
              0xC6,
              0xC7,
              0xC9,
              0xCA,
              0xCB,
              0xCD,
              0xCE,
              0xCF
            ] do
    case data do
      <<_precision, height::16, width::16, _rest::binary>> -> {:ok, width, height}
      _ -> {:error, :invalid_image_dimensions}
    end
  end

  defp scan_jpeg_segments(<<0xFF, marker, segment_length::16, _data::binary>>)
       when marker not in [0xD8, 0xD9] and segment_length < 2,
       do: {:error, :invalid_image_dimensions}

  defp scan_jpeg_segments(<<0xFF, marker, segment_length::16, data::binary>>)
       when marker not in [0xD8, 0xD9] and segment_length >= 2 and
              byte_size(data) >= segment_length - 2 do
    skip = segment_length - 2
    <<_segment::binary-size(skip), rest::binary>> = data
    scan_jpeg_segments(rest)
  end

  defp scan_jpeg_segments(<<0xFF, marker, segment_length::16, _data::binary>>)
       when marker not in [0xD8, 0xD9] and segment_length >= 2,
       do: {:error, :invalid_image_dimensions}

  defp scan_jpeg_segments(<<0xFF, marker, rest::binary>>)
       when marker in [0xD8, 0xD9, 0x01] or (marker >= 0xD0 and marker <= 0xD7),
       do: scan_jpeg_segments(rest)

  defp scan_jpeg_segments(<<>>), do: {:error, :invalid_image_dimensions}
  defp scan_jpeg_segments(_), do: {:error, :invalid_image_dimensions}

  defp webp_dimensions(<<"RIFF", _file_size::little-32, "WEBP", chunk::binary>>) do
    case chunk do
      <<"VP8X", _chunk_size::little-32, _flags, width_minus_one::little-24,
        height_minus_one::little-24, _::binary>> ->
        {:ok, width_minus_one + 1, height_minus_one + 1}

      <<"VP8 ", _chunk_size::little-32, _frame_tag::binary-size(3), 0x9D, 0x01, 0x2A,
        width_raw::little-16, height_raw::little-16, _::binary>> ->
        {:ok, Bitwise.band(width_raw, 0x3FFF), Bitwise.band(height_raw, 0x3FFF)}

      <<"VP8L", _chunk_size::little-32, 0x2F, bits::little-32, _::binary>> ->
        width = Bitwise.band(bits, 0x3FFF) + 1
        height = Bitwise.band(Bitwise.bsr(bits, 14), 0x3FFF) + 1
        {:ok, width, height}

      _ ->
        {:error, :invalid_image_dimensions}
    end
  end

  defp webp_dimensions(_), do: nil

  defp validate_avatar_dimensions(width, height)
       when width >= @avatar_min_dimension and height >= @avatar_min_dimension,
       do: :ok

  defp validate_avatar_dimensions(_width, _height), do: {:error, :image_too_small}

  defp build_uuid_filename(extension, basename \\ nil) do
    extension = extension |> String.trim() |> String.trim_leading(".")
    extension = if extension == "", do: "bin", else: extension

    case basename do
      nil -> "#{Ecto.UUID.generate()}.#{extension}"
      value -> "#{Ecto.UUID.generate()}-#{sanitize_basename(value)}.#{extension}"
    end
  end

  defp sanitize_basename(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "upload"
      sanitized -> String.slice(sanitized, 0, 60)
    end
  end
end
