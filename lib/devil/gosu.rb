require 'texplay'
require 'devil'

# monkey patches for TexPlay module (and by proxy the Gosu::Image class)
module TexPlay

    # save a Gosu::Image to +file+
    # This method is only available if require 'devil/gosu' is used
    def save(file)
        capture { 
            to_devil.save(file)
        }
    end

    # convert a Gosu::Image to a Devil::Image.
    # This method is only available if require 'devil/gosu' is used
    def to_devil
        devil_img = nil
        capture {
            devil_img = Devil.from_blob(self.to_blob, self.width, self.height)
            devil_img.flip
        }
        devil_img
    end
end

# monkey patches for Gosu::Window class
class Gosu::Window

    # return a screenshot of the framebuffer as a Devil::Image.
    # This method is only available if require 'devil/gosu' is used
    def screenshot
        require 'opengl'

        canvas_texture_id = glGenTextures(1).first
        
        img = nil
        self.gl do
            glEnable(GL_TEXTURE_2D)
            glBindTexture(GL_TEXTURE_2D, canvas_texture_id)
            
            glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, 1)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, self.width, self.height, 0, GL_RGB, GL_UNSIGNED_BYTE, "\0" * self.width * self.height * 3)
            
            glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 0, 0, self.width, self.height, 0)

            data = glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE)
            img = Devil.from_blob(data, self.width, self.height)
        end
        
        img
    end
end

class Gosu::Image
    class << self
        alias_method :original_new_redux, :new
        
        # monkey patching to support multiple image formats.
        # This method is only available if require 'devil/gosu' is used
        def new(window, file, &block)
            if file.respond_to?(:to_blob) || file =~ /\.(bmp|png)$/
                original_new_redux(window, file, &block)
            else 
                original_new_redux(window, Devil.load(file), &block)
            end
        end
    end
end

class Devil::Image

    # convert a Devil::Image to a Gosu::Image.
    # Must provide a +window+ parameter, as per Gosu::Image#new()
    # This method is only available if require 'devil/gosu' is used
    def to_gosu(window)
        Gosu::Image.new(window, self)
    end
    
    # display the Devil images on screen utilizing the Gosu library for visualization
    # if +x+ and +y+ are specified then show the image centered at this location, otherwise
    # draw the image at the center of the screen 
    # This method is only available if require 'devil/gosu' is used
    def show(x = 512, y = 384)
        if !Devil.const_defined?(:Window)
            c = Class.new(Gosu::Window) do
                attr_accessor :show_list
                
                def initialize
                    super(1024, 768, false)
                    @show_list = []
                end

                def draw    # :nodoc:
                    @show_list.each { |v| v[:image].draw_rot(v[:x], v[:y], 1, 0) }
                end
            end

            Devil.const_set :Window, c
        end
        
        if !defined? @@window
            @@window ||= Devil::Window.new

            at_exit { @@window.show }
        end
        
        @@window.show_list.push :image => Gosu::Image.new(@@window, self), :x => x, :y => y
    end
end
