defmodule EvercamMedia.Snapshot.Storage do
  require Logger
  alias Calendar.Date
  alias Calendar.DateTime
  alias Calendar.Strftime
  alias EvercamMedia.Util

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  def thumbnail_save(camera_exid, image) do
    try do
      task = Task.async(fn() ->
        File.open("#{@root_dir}/#{camera_exid}/snapshots/thumbnail.jpg", [:write, :binary, :raw], fn(file) ->
          IO.binwrite(file, image)
        end)
      end)
      Task.await(task, :timer.seconds(2))
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  def thumbnail_load(camera_exid) do
    try do
      task = Task.async(fn() ->
        {:ok, content} = File.open("#{@root_dir}/#{camera_exid}/snapshots/thumbnail.jpg", [:read, :binary, :raw], fn(file) ->
          IO.binread(file, :all)
        end)
        content
      end)
      Task.await(task, :timer.seconds(1))
    catch _type, error ->
      Util.error_handler(error)
      Util.unavailable
    end
  end

  def thumbnail_exists?(camera_exid) do
    try do
      task = Task.async(fn() ->
        File.exists?("#{@root_dir}/#{camera_exid}/snapshots/thumbnail.jpg")
      end)
      Task.await(task, :timer.seconds(1))
    catch _type, error ->
      Util.error_handler(error)
      false
    end
  end

  def save(camera_exid, timestamp, image, notes) do
    app_name = parse_note(notes)
    directory_path = construct_directory_path(camera_exid, timestamp, app_name)
    file_name = construct_file_name(timestamp)
    try do
      task = Task.async(fn() ->
        :filelib.ensure_dir(to_char_list(directory_path))
      end)
      Task.await(task, :timer.seconds(2))
    catch _type, error ->
      Util.error_handler(error)
    end
    try do
      task = Task.async(fn() ->
        File.open("#{directory_path}#{file_name}", [:write, :binary, :raw], fn(file) ->
          IO.binwrite(file, image)
        end)
      end)
      Task.await(task, :timer.seconds(1))
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  def load(camera_exid, snapshot_id, notes) do
    try do
      task = Task.async(fn() ->
        app_name = parse_note(notes)
        timestamp =
          snapshot_id
          |> String.split("_")
          |> List.last
          |> Util.snapshot_timestamp_to_unix
        directory_path = construct_directory_path(camera_exid, timestamp, app_name)
        file_name = construct_file_name(timestamp)
        {:ok, content} = File.open("#{directory_path}#{file_name}", [:read, :binary, :raw], fn(file) ->
          IO.binread(file, :all)
        end)
        content
      end)
      Task.await(task, :timer.seconds(1))
    catch _type, error ->
      Util.error_handler(error)
      Util.unavailable
    end
  end

  def exists?(camera_exid, snapshot_id, notes) do
    try do
      task = Task.async(fn() ->
        app_name = parse_note(notes)
        timestamp =
          snapshot_id
          |> String.split("_")
          |> List.last
          |> Util.snapshot_timestamp_to_unix
        directory_path = construct_directory_path(camera_exid, timestamp, app_name)
        file_name = construct_file_name(timestamp)
        File.exists?("#{directory_path}#{file_name}")
      end)
      Task.await(task, :timer.seconds(1))
    catch _type, error ->
      Util.error_handler(error)
      false
    end
  end

  def cleanup(cloud_recording) do
    try do
      task = Task.async(fn() ->
        unless cloud_recording.storage_duration == -1 do
          camera_exid = cloud_recording.camera.exid
          seconds_to_day_before_expiry = (cloud_recording.storage_duration) * (24 * 60 * 60) * (-1)
          day_before_expiry =
            DateTime.now_utc
            |> DateTime.advance!(seconds_to_day_before_expiry)
            |> DateTime.to_date

          Logger.info "[#{camera_exid}] [snapshot_delete_disk]"
          Path.wildcard("#{@root_dir}/#{camera_exid}/snapshots/recordings/????/??/??/")
          |> Enum.each(fn(path) -> delete_if_expired(camera_exid, path, day_before_expiry) end)
        end
      end)
      Task.await(task, :timer.seconds(25))
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  defp delete_if_expired(camera_exid, path, day_before_expiry) do
    try do
      task = Task.async(fn() ->
        date =
          path
          |> String.replace_leading("#{@root_dir}/#{camera_exid}/snapshots/recordings/", "")
          |> String.replace("/", "-")
          |> Date.Parse.iso8601!

        if Calendar.Date.before?(date, day_before_expiry) do
          Logger.info "[#{camera_exid}] [snapshot_delete_disk] [#{Date.Format.iso8601(date)}]"
          dir_path = Strftime.strftime!(date, "#{@root_dir}/#{camera_exid}/snapshots/recordings/%Y/%m/%d")
          Porcelain.shell("find '#{dir_path}' -delete")
        end
      end)
      Task.await(task, :timer.seconds(5))
    catch _type, error ->
      Util.error_handler(error)
    end
  end

  def construct_directory_path(camera_exid, timestamp, app_dir) do
    timestamp
    |> DateTime.Parse.unix!
    |> Strftime.strftime!("#{@root_dir}/#{camera_exid}/snapshots/#{app_dir}/%Y/%m/%d/%H/")
  end

  def construct_file_name(timestamp) do
    timestamp
    |> DateTime.Parse.unix!
    |> Strftime.strftime!("%M_%S_%f")
    |> format_file_name
  end

  def format_file_name(<<file_name::bytes-size(6)>>) do
    "#{file_name}000" <> ".jpg"
  end

  def format_file_name(<<file_name::bytes-size(9), _rest :: binary>>) do
    "#{file_name}" <> ".jpg"
  end

  def parse_note(notes) do
    case notes do
      "Evercam Proxy" -> "recordings"
      "Evercam Thumbnail" -> "thumbnail"
      "Evercam Timelapse" -> "timelapse"
      "Evercam SnapMail" -> "snapmail"
      _ -> "archives"
    end
  end
end
