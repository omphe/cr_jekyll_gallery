# add a css file somewhere?

# {% cr_gallery thumbnail_width thumbnail_height root_dir %}
#foo.jpg The caption for the image
#bar.jpg The second caption
#baz.png 

# {% endcr_gallery
# start the markup for the gallery tag (pilfer this from nextgengallery on wordpress)
# create a link for each of the thumbnails linking to the real image or a javascript output, put in the thumbnail markup
# register the declared tag


# TODO
# Make the gallery image an inherited static file
# Get the paths sorted out
# Put the markup into a tag/erb  - or put
# Clean up the generated files afterward and gitignore the generated files


require 'rmagick'
include Magick

class CRGalleryImage < Jekyll::StaticFile
  attr_accessor :caption, :max_dimension, :source_path, :width, :height, :thumbnail, :gallery_name

  def initialize(site,gallery_name,image_name)
    super(site, site.config['source'], File.join('images','galleries', gallery_name), image_name)
    @gallery_name = gallery_name
    @max_dimension = site.config['cr_gallery']['max_dimension']

    generate_image
  end

  def generate_image
    image = read_image
    resized = image.resize_to_fit(@max_dimension)
    resized.write(File.join(@base,@site.config['cr_gallery']['destination_dir'], @gallery_name, @name))

    @width = resized.rows
    @height = resized.columns

    image.destroy!
    resized.destroy!
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

      output = '<ul>'
      @images.each do |image|
       
        site_image = CRGalleryImage.new(context.registers[:site], @sourceImageDirectory, image[:imageName])
        if(image[:caption])
          site_image.caption = image[:caption]
        end

        thumbnail_image = CRGalleryThumbnail.new(context.registers[:site], @sourceImageDirectory, image[:imageName])
        
        output << '<li>' 
        output << '<img src="' + site_image.destination('/') + '" '

        if(thumbnail_image.width)
          output << 'width="' + thumbnail_image.width.to_s + '"' 
        end
        if(thumbnail_image.height)
          output << 'height="' + thumbnail_image.height.to_s + '"'
        end
        output << ' />'
        
        if site_image.caption 
          output << ' (' + site_image.caption + ') '
        end
        output << '</li>'
        
        context.registers[:site].static_files << site_image
        context.registers[:site].static_files << thumbnail_image

      end
      
      output << '</ul>'
      output
    end
  end
end

Liquid::Template.register_tag('cr_gallery', Jekyll::CRGalleryTag)
