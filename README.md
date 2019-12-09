# Arthropod-hls-video-encoder

## Installation

```
gem install arthropod_hls_video_encoder
```

## Usage

Just run it with the required arguments.
```shell
$ arthropod_hls_video_encoder -h

Usage: arthropod_hls_video_encoder [options]
    -q, --queue [string]             SQS queue name
    -i, --access-key-id [string]     AWS access key ID, default to the AWS_ACCESS_KEY_ID environment variable
    -k, --secret-access-key [string] AWS secret access key, default to the AWS_SECRET_ACCESS_KEY environment variable
    -r, --region [string]            AWS region, default to the AWS_REGION environment variable
```

Example of client side call:
```ruby
result = Arthropod::Client.push(queue_name: "hls_video_encoder", body: {
  video_url: "https://s3-#{ENV['S3_REGION']}.amazonaws.com/#{ENV['S3_BUCKET']}/#{medium.temporary_key}",
  root_dir: Digest::SHA1.hexdigest("#{ENV["SECURE_UPLOADER_KEY"]}#{medium.uuid}").insert(3, '/'),
  aws_access_key_id: ENV['S3_ACCESS_KEY_ID'],
  aws_secret_access_key: ENV['S3_SECRET_ACCESS_KEY'],
  region: ENV['S3_REGION'],
  endpoint: ENV['S3_ENDPOINT'],
  host: ENV['S3_HOST'],
  bucket: ENV['S3_BUCKET'],
  profiles: [
    {
      codec: "libx264",
      bandwidth: 1500000,
      resolution: 720,
      name: 'high',
    },
    {
      codec: "libx264",
      bandwidth: 800000,
      resolution: 720,
      name: 'low'
    }
  ]
})
```

* `video_url`: the URL of the video you want to transcode to HLS
* `root`: the destination directory in your bucket
* `aws_access_key_id`: an AWS access key to access your bucket
* `aws_secret_access_key`:  an AWS secret access key to access your bucket
* `region`: the region of your bucket
* `endpoint`: the endpoint of your S3 instance if you have one (useful for Minio)
* `host`: the host of your S3 instance if you have one (useful for Minio)
* `bucket`: your bucket name
* `profiles`: the HLS profile you want to generate

The result object is a follow.

```ruby
{
  key: "[string]",
  thumbnail_key: "[string]",
  small_thumbnail_key: "[string]",
  preview_key: "[string]",
  duration: "[string]"
}
```

* `key`: the key the root HLS file in your bucket
* `thumbnail_key`: the key of the auto-generated thumbnail (the thumbnail is taken at half the video time)
* `small_thumbnail_key`: same thing, but with a smaller thumbnail
* `preview_key`: a GIF preview of your video
* `duration`: the duration of the video

*Both the input and output are very opiniated and follow my needs*
