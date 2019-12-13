require 'shellwords'
require 'json'
require 'securerandom'
require 'fog/aws'

module ArthropodHlsVideoEncoder
  class Encoder
    attr_reader :video_url, :aws_access_key_id, :aws_secret_access_key, :region, :endpoint, :host, :bucket, :profiles, :job_id, :root_dir

    def initialize(video_url:, root_dir:, aws_access_key_id:, aws_secret_access_key:, region:, endpoint:, host:, bucket:, profiles:)
      @video_url = video_url
      @root_dir = root_dir
      @aws_access_key_id = aws_access_key_id
      @aws_secret_access_key = aws_secret_access_key
      @region = region
      @endpoint = endpoint
      @host = host
      @bucket = bucket
      @profiles = profiles
      @job_id = SecureRandom.uuid
    end

    def perform!
      Dir.mktmpdir do |wdir|
        @wdir = wdir

        download_input!

        {
          key: perform_video_encoding!,
          thumbnail_key: get_thumbnail!,
          small_thumbnail_key: get_small_thumbnail!,
          preview_key: get_preview!,
          duration: get_duration!
        }
      end
    end

    def download_input!
      unless File.exists? input_path
        call_command("curl #{Shellwords.escape(video_url)} -s -o #{input_path}")
      end
    end

    def perform_video_encoding!
      # Reencode
      ffmpeg_configurations = profiles.map { |profile| ffmpeg_configuration_for(profile) }.join(" ")

      call_command("ffmpeg -i #{input_path} -pass 1 -passlogfile #{@wdir}/log #{ffmpeg_configurations}")
      call_command("ffmpeg -i #{input_path} -pass 2 -passlogfile #{@wdir}/log #{ffmpeg_configurations}")

      # create index file
      indices = profiles.map do |profile|
        [
          "#EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=#{profile["bandwidth"]}",
          "#{profile["name"]}_#{job_id}.m3u8"
        ]
      end
      File.open("#{@wdir}/index.m3u8", 'w') { |f| f.write("#EXTM3U\n" + indices.flatten.join("\n")) }

      # Upload to storage
      Dir["#{@wdir}/*.{ts,m3u8}"].each do |path|
        upload(path, "#{root_dir}/#{File.basename(path)}")
      end

      "#{root_dir}/index.m3u8"
    end

    def get_thumbnail!
      call_command "ffmpeg -i #{input_path} -vcodec mjpeg -vframes 1 -filter:v scale=\"1080:-1\" -q:v 10 -an -f rawvideo -ss #{video_middle} #{thumbnail_path}"

      "#{root_dir}/thumbnail.jpg".tap do |key|
        upload(thumbnail_path, key)
      end
    end

    def get_small_thumbnail!
      call_command "ffmpeg -i #{input_path} -vcodec mjpeg -vframes 1 -filter:v scale=\"640:-1\" -q:v 10 -an -f rawvideo -ss #{video_middle} #{small_thumbnail_path}"

      "#{root_dir}/small_thumbnail.jpg".tap do |key|
        upload(small_thumbnail_path, key)
      end
    end

    def get_preview!
      call_command "ffmpeg -y -ss #{video_middle} -t 3 -i #{input_path} -vf fps=10,scale=320:-1:flags=lanczos,palettegen #{palette_path}"
      call_command "ffmpeg -ss #{video_middle} -t 3 -i #{input_path} -i #{palette_path} -filter_complex \"fps=10,scale=320:-1:flags=lanczos[x];[x][1:v]paletteuse\" #{preview_path}"

      "#{root_dir}/preview.gif".tap do |key|
        upload(preview_path, key)
      end
    end

    def get_duration!
      output = JSON.parse(`ffprobe -of json -show_format_entry name -show_format #{input_path} -loglevel quiet`)
      output["format"]["duration"].to_i
    end

    protected

    def input_path
      Shellwords.escape("#{@wdir}/input")
    end

    def thumbnail_path
      Shellwords.escape("#{@wdir}/thumbnail.jpeg")
    end

    def small_thumbnail_path
      Shellwords.escape("#{@wdir}/small_thumbnail.jpeg")
    end

    def preview_path
      Shellwords.escape("#{@wdir}/preview.gif")
    end

    def palette_path
      Shellwords.escape("#{@wdir}/palette.png")
    end

    def video_middle
      Shellwords.escape(`ffmpeg -i #{input_path} 2>&1 | grep Duration | awk '{print $2}' | tr -d , | awk -F ':' '{print ($3+$2*60+$1*3600)/2}'`.chomp)
    end

    def call_command(command)
      system(command, out: File::NULL, err: File::NULL)
      raise if $?.to_i != 0
    end

    def ffmpeg_configuration_for(profile)
      "-vcodec #{profile["codec"]} -acodec aac -strict -2 -q:a 5 -ac 1 -r 25 -profile:v baseline -vf scale='trunc(oh*a/2)*2:#{profile["resolution"]}' -preset slow -b:v #{profile["bandwidth"]} -maxrate #{profile["bandwidth"]} -pix_fmt yuv420p -flags -global_header -hls_time 10 -hls_list_size 0 #{@wdir}/#{profile["name"]}_#{job_id}.m3u8"
    end

    def storage
      @storage ||= Fog::Storage.new({
        provider:              'AWS',
        aws_access_key_id:     aws_access_key_id,
        aws_secret_access_key: aws_secret_access_key,
        region:                region,
        endpoint:              endpoint,
        host:                  host,
        path_style:            true
      })
      @storage.directories.get(bucket)
    end

    def upload(path, key)
      open(path) do |file|
        storage.files.create({
          key: key,
          body: file,
          public: true
        })
      end.public_url
    end
  end
end
