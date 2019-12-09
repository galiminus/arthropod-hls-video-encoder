# -*- encoding: utf-8 -*-

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "arthropod_hls_video_encoder/version"

Gem::Specification.new do |gem|
  gem.name          = "arthropod_hls_video_encoder"
  gem.version       = ArthropodHlsVideoEncoder::VERSION
  gem.authors       = ["Victor Goya"]
  gem.email         = ["goya.victor@gmail.com"]
  gem.description   = "HLS video encoder using Arthropod"
  gem.summary       = "HLS video encoder using Arthropod"

  gem.files         = `git ls-files -z`.split("\x0")
  gem.executables   = %w(arthropod_hls_video_encoder)
  gem.require_paths = ["lib"]
  gem.bindir        = 'bin'

  gem.licenses      = ["MIT"]

  gem.required_ruby_version = "~> 2.0"

  gem.add_dependency 'arthropod', '= 0.0.2'
  gem.add_dependency 'aws-sdk-sqs'
  gem.add_dependency 'fog-aws'

  gem.add_development_dependency "byebug"
end
