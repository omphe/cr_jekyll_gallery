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
  attr_accessor :imageName, :thumbnail_name, :caption, :maxDimension, :maxThumbnailDimension, :sourcePath, :fileExtension, :thumbnailWidth, :thumbnailHeight, :width, :height
  attr_accessor :thumbnail

  def initialize(site,base,dir,name)

        siteImage.maxDimension = @maxDimension
        siteImage.maxThumbnailDimension = @maxThumbnailDimension

      @maxDimension = site.config['cr_gallery']['max_dimension']
      @maxThumbnailDimension = site.config['cr_gallery']['max_thumbnail_dimension']
      @sourcePath = File.join(site.config['source'], site.config['cr_gallery']['source_dir'], @sourceImageDirectory)
      @destinationPath = File.join(site.config['source'], site.config['cr_gallery']['destination_dir'], @sourceImageDirectory)

    super
  end

  def existsAtPath?(path)
    File.exists?(File.join(path, @imageName))
  end


  def createFullSizeAtPath(path)
    image = sourceImage
    resized = image.resize_to_fit(@maxDimension)
    resized.write(File.join(path,  @imageName))

    @width = resized.rows
    @height = resized.columns

    image.destroy!
    resized.destroy!
  end


  def createThumbnailAtPath(path)
    image = sourceImage
    resized = image.resize_to_fit(@maxThumbnailDimension)
    resized.write(File.join(path, @thumbnail_name))

    @thumbnailWidth = resized.rows
    @thumbnailHeight = resized.columns

    image.destroy!
    resized.destroy!
  end


  def sourceImage
    return Image.read(File.join(@sourcePath, @imageName)).first
  end

  def imageName=(name)
    @imageName = name
    @fileExtension = File.extname(name)
    @thumbnail_name = File.basename(name, '.*') + '_thumbnail' + @fileExtension
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
#      p context.registers[:site].categories

#      context.registers[:site].static_files << Jekyll::StaticFile.new(context.registers[:site],'source','_galleries/foobar','mytest.txt')
      loadConfig(context.registers[:site].config)

      if(!galleryDirExists?)
        createGalleryDirectory
      end


      output = '<ul>'
      @images.each do |image|
        siteImage = CRGalleryImage.new(context.registers[:site], 
                                   context.registers[:site].source, 
                                   File.join('images', 'galleries', @sourceImageDirectory),
                                   image[:imageName])

        siteImage.imageName = image[:imageName]

        if(image[:caption])
          siteImage.caption = image[:caption]
        end


        if(siteImage.existsAtPath?(@sourcePath))#  &&  !image.existsAtPath?(@destinationPath))
          siteImage.sourcePath = @sourcePath
          siteImage.createFullSizeAtPath(@destinationPath)
          siteImage.createThumbnailAtPath(@destinationPath)
        end
        
 #       output << '<li>' 
 #       output << '<img src="' +  '../images/galleries/' + @sourceImageDirectory + '/' + siteImage.imageName + '_thumbnail.' + siteImage.fileExtension + '" '


#        if(image.thumbnailWidth)
#          output << 'width="' + siteImage.thumbnailWidth.to_s + '"' 
#        end
#         if(image.thumbnailHeight)
#           output << 'height="' + siteImage.thumbnailHeight.to_s + '"'
#         end
#        output << ' />'
#  
#        if image.caption 
#          output << ' (' + siteImage.caption + ') '
#        end
#        output << '</li>'
#     end
      
#      output << '</ul>'
#      output
      
        context.registers[:site].static_files << siteImage
        context.registers[:site].static_files << siteImage.thumbnail
      end
    end


    def galleryDirExists?
      return Dir.exists?(@destinationPath)
    end

    def createGalleryDirectory
      if(!Dir.exists?(File.join(config['source'] , config['cr_gallery']['destination_dir'])))
        Dir.mkdir(File.join(config['source'], config['cr_gallery']['destination_dir']))
      end
      Dir.mkdir(@destinationPath)
    end

    def loadConfig(config)
      @config = config
      @maxDimension = config['cr_gallery']['max_dimension']
      @maxThumbnailDimension = config['cr_gallery']['max_thumbnail_dimension']
      @sourcePath = File.join(config['source'], config['cr_gallery']['source_dir'], @sourceImageDirectory)
      @destinationPath = File.join(config['source'], config['cr_gallery']['destination_dir'], @sourceImageDirectory)
    end

  end
end

Liquid::Template.register_tag('cr_gallery', Jekyll::CRGalleryTag)


#if __FILE__ == $0
#  require 'test/unit'

#  class TC_MyTest < Test::Unit::TestCase
#    def setup
#      @result = Delicious::tag('37signals', 'svn', 5)
#    end

#    def test_size
#      assert_equal(@result.size, 5)
#    end

#    def test_bookmark
#      bookmark = @result.first
#      assert_equal(bookmark.title, 'Mike Rundle: "I now realize why larger weblogs are switching to WordPress...')
#      assert_equal(bookmark.description, "...when a site posts a dozen or more entries per day for the past few years, rebuilding the individual entry archives takes a long time. A long, long time. &amp;lt;strong&amp;gt;About 32 minutes each rebuild.&amp;lt;/strong&amp;gt;&amp;quot;")
#      assert_equal(bookmark.link, "http://businesslogs.com/business_logs/launch_a_socialites_life.php")
#    end
#  end
#end

