# Copyright (c) 2011 Branden Faulls, http://www.clockworkrobot.co.uk/
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# Usage

# {% cr_gallery thumbnail_width thumbnail_height root_dir %}
#foo.jpg The caption for the image
#bar.jpg The second caption
#baz.png 

# {% endcr_gallery}

# TODO
# Put the markup into a tag/erb  - or put
# Clean up the generated files afterward and gitignore the generated files

require 'rubygems'
require 'RMagick'
include Magick

class CRGalleryImage < Jekyll::StaticFile
  attr_accessor :caption, :max_dimension, :max_width, :max_height, :source_path, :width, :height, :thumbnail, :gallery_name

  def initialize(site,gallery_name,image_name)
    super(site, site.config['source'], File.join('images','galleries', gallery_name), image_name)
    @gallery_name = gallery_name
# We don't really need the max_dimension in the base CRGalleryImage class if we are going to use width & height
    @max_dimension = site.config['cr_gallery']['max_dimension']
    @max_width = site.config['cr_gallery']['max_width']
    @max_height = site.config['cr_gallery']['max_height']

    generate_image
  end

  def generate_image
    image = read_image
    resized = resize_image(image)
    resized.write(File.join(@base,@site.config['cr_gallery']['destination_dir'], @gallery_name, @name))

    @width = resized.columns
    @height = resized.rows

    image.destroy!
    resized.destroy!
  end

  def resize_image(image)
    return image.resize_to_fit(@max_width, @max_height)
  end

  def read_image
    return Image.read(File.join(@base,@site.config['cr_gallery']['source_dir'], @gallery_name, @name)).first
  end
end

class CRGalleryThumbnail < CRGalleryImage

  attr_accessor :fullsize_name

  def initialize(site,gallery_name,fullsize_name)
    @fullsize_name = fullsize_name
    name = File.basename(fullsize_name, '.*') + '_thumbnail' + File.extname(fullsize_name)
    super(site, gallery_name, name)
    @max_dimension = site.config['cr_gallery']['max_thumbnail_dimension']

    generate_image
    
  end
  
  def resize_image(image)
    return image.resize_to_fill(@max_dimension)
  end


  def read_image
    return Image.read(File.join(@base,@site.config['cr_gallery']['source_dir'], @gallery_name, @fullsize_name)).first
  end

end



module Jekyll

  class CRGalleryTag < Liquid::Block
    include Liquid::StandardFilters
    Syntax = /(#{Liquid::QuotedFragment}+)?/ 

    attr_accessor :images, :sourceImageDirectory, :sourcePath, :destination_path, :config, :maxDimension, :maxThumbnailDimension

    def initialize(tag_name, markup, tokens)
      @attributes = {}
      
      # Parse parameters
      if markup =~ Syntax
        markup.scan(Liquid::TagAttributes) do |key, value|
          #p key + ":" + value
          @attributes[key] = value
        end
      else
        raise SyntaxError.new("Syntax Error in 'cr_gallery' - Valid syntax: cr_gallery img_dir:x]")
      end

      @sourceImageDirectory = @attributes['img_dir']

      @images = []
      tagContents = tokens[0].split(/\n/).map {|x| x.strip }.reject {|x| x.empty? }   

      tagContents.each do |tag|
        taggedImage = {}

        if(tag.index(' ') == nil) 
          taggedImage[:imageName] = tag
        else
          taggedImage[:imageName] = tag[0..tag.index(' ')].strip
          taggedImage[:caption] = tag[tag.index(' ')..tag.length].strip
        end

        @images << taggedImage
      end

      super
    end

    def render(context)
      config = context.registers[:site].config

      FileUtils.mkdir_p(File.join(config['source'],config['cr_gallery']['destination_dir'], @sourceImageDirectory))

      output = '<div id="gallery"><ul>'
      @images.each do |image|
       
        site_image = CRGalleryImage.new(context.registers[:site], @sourceImageDirectory, image[:imageName])
        if(image[:caption])
          site_image.caption = image[:caption]
        end

        thumbnail_image = CRGalleryThumbnail.new(context.registers[:site], @sourceImageDirectory, image[:imageName])
        
        output << '<li>' 
        output << '<a href="' + site_image.destination('/') + '" '
        if site_image.caption 
          output << 'title="' + site_image.caption + '" '
        end        

        output << '>'
        output << '<img src="' + thumbnail_image.destination('/') + '" '

        if(thumbnail_image.width)
          output << 'width="' + thumbnail_image.width.to_s + '"' 
        end
        if(thumbnail_image.height)
          output << 'height="' + thumbnail_image.height.to_s + '"'
        end
        output << ' />'
        output << '</a>'
        output << '</li>'
        
        context.registers[:site].static_files << site_image
        context.registers[:site].static_files << thumbnail_image

      end
      
      output << '</ul>'
      output << '</div>'
      output
    end
  end
end

Liquid::Template.register_tag('cr_gallery', Jekyll::CRGalleryTag)
