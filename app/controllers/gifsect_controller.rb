require 'net/http'
require 'digest/md5'
require 'fileutils'
require 'RMagick'
require 'json'
include Magick

class GifsectController < ApplicationController
  def do
    @url = sanitise_url(request.fullpath[1..-1])
    render formats: [:html]
  end

  def metadata
    render json: { status: :ok, path: remote_hash_path('gif_data', retrieve_file(sanitise_url(request.fullpath[10..-1]))) }
  rescue Exception => e
    render json: { status: :failed, message: e.message }
  end

  private
  def sanitise_url(url)
    url = 'http://' + url[6..-1] if url.downcase.start_with?('http:/') and not url.downcase.start_with?('http://')
    url = 'https://' + url[7..-1] if url.downcase.start_with?('https://') and not url.downcase.start_with?('https://')
    url = 'http://' + url unless url.downcase.start_with?('http://', 'http://')

    url
  end

  def retrieve_file(url)
    uri = URI.parse(url)
    uri.host.downcase!

    # See if we have a pointer from url hash to data hash
    ptr = hash_path('url_ptr', hash(uri.to_s))

    have_data = File.exist?(ptr)

    if have_data # Check for valid pointer
      data_hash = File.read(ptr)
      data_path = hash_path('gif_data', data_hash)
      have_data = File.exist?(data_path)
      have_processed_data = File.exist?(File.join(data_path, 'metadata.json'))
    end

    data_hash = download_gif(uri) unless have_data
    process_gif(data_hash) unless have_processed_data

    data_hash
  end

  def process_gif(hash)
    data_path = hash_path('gif_data', hash)
    source = File.join(data_path, 'source.gif')
    images = Image.read(source)
    raise 'GIF image has no frames' unless images.length > 0
    first = images[0]
    ticks = (first.ticks_per_second || 100).to_f
    bg = (first.background_color.is_a?(String)? Pixel.from_color(first.background_color): first.background_color)
    bg = '#' + [bg.red, bg.green, bg.blue].map{|p| '%02X' % ((p >> QuantumDepth - 8) & 0xff)}.join('')
    metadata = {
        background: bg,
        width: first.page.width,
        height: first.page.height,
        animStart: 0,
        frames: [],
        delay: first.delay.nil?? (1000.0/ticks).to_i: first.delay.to_f / (ticks * 1000).to_i
    }


    #rec = Image.new(first.columns, first.rows)
    images.each_with_index do |image, index|
      ticks = (image.ticks_per_second || 100).to_f
      md = {}
      del = image.delay.nil?? metadata[:delay]: ((image.delay.to_f / ticks) * 1000).to_i
      md[:delay] = del unless del == metadata[:delay]
      metadata[:anim_start] = index if image.start_loop
      metadata[:frames] << md
      image.write(File.join(data_path, "#{index}.png"))
      md[:x] = image.page.x unless image.page.x == 0
      md[:y] = image.page.y unless image.page.y == 0
      #rec.composite!(image, image.page.x, image.page.y, SrcOverCompositeOp)
      #rec.write(File.join(data_path, "#{index}.png"))
    end
    File.open(File.join(data_path, 'metadata.json'), 'w') { |file| file.write(JSON.generate(metadata)) }
    nil
  end

  def download_gif(uri)
    ptr = hash_path('url_ptr', hash(uri.to_s))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme.downcase == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    res = http.get(uri.request_uri)
    raise "#{res.code} #{res.message}" unless res.kind_of?(Net::HTTPSuccess)
    gifdata = res.body
    data_hash = hash(gifdata)
    path = hash_path('gif_data', data_hash)
    FileUtils.makedirs(path)
    gif_path = File.join(path, 'source.gif')
    File.open(ptr, 'w') { |file| file.write(data_hash) } # Store ptr from url to data
    File.open(gif_path, 'wb') { |file| file.write(gifdata) } # Store data
    data_hash
  end

  def hash(data)
    Digest::MD5.hexdigest(data)
  end

  def remote_hash_path(root, digest, break_depth=3)
    parts = digest.scan(/.{1,2}/)
    parts[break_depth] = parts[break_depth..-1] * ''
    parts = parts.shift(break_depth+1)
    path = File.join(root, *parts)
    path
  end

  def hash_path(root, digest, break_depth=3)
    path = File.join(Rails.root, 'public', remote_hash_path(root, digest, break_depth))
    FileUtils.mkpath(File.dirname(path))
    path
  end
end