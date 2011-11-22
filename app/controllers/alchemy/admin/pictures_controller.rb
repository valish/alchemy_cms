module Alchemy
	module Admin
		class PicturesController < Alchemy::Admin::BaseController
			protect_from_forgery :except => [:create]

			cache_sweeper Alchemy::PicturesSweeper, :only => [:update, :destroy]

			respond_to :html, :js

			def index
				@size = params[:size] || 'medium'
				if params[:per_page] == 'all'
					@pictures = Picture.where("name LIKE '%#{params[:query]}%'").order(:name)
				else
					@pictures = Picture.where("name LIKE '%#{params[:query]}%'").paginate(
						:page => params[:page] || 1,
						:per_page => pictures_per_page_for_size(@size)
					).order(:name)
				end
				if in_overlay?
					archive_overlay
				else
					# render index.html.erb
				end
			end

			def new
				@picture = Picture.new
				@while_assigning = params[:while_assigning] == 'true'
				@size = params[:size] || 'medium'
				if in_overlay?
					@while_assigning = true
					@content = Content.find(params[:content_id], :select => 'id') if !params[:content_id].blank?
					@element = Element.find(params[:element_id], :select => 'id')
					@options = hashified_options
					@page = params[:page]
					@per_page = params[:per_page]
				end
				render :layout => false
			end

			def create
				@picture = Picture.new(:image_file => params[:Filedata])
				@picture.name = @picture.image_filename
				@picture.save
				@size = params[:size] || 'medium'
				if in_overlay?
					@while_assigning = true
					@content = Content.find(params[:content_id], :select => 'id') if !params[:content_id].blank?
					@element = Element.find(params[:element_id], :select => 'id')
					@options = hashified_options
					@page = params[:page] || 1
					@per_page = pictures_per_page_for_size(@size)
				end
				if params[:per_page] == 'all'
					@pictures = Picture.where("name LIKE '%#{params[:query]}%'").order(:name)
				else
					@pictures = Picture.where("name LIKE '%#{params[:query]}%'").paginate(
						:page => (params[:page] || 1),
						:per_page => pictures_per_page_for_size(@size)
					).order(:name)
				end
				@message = _('Picture %{name} uploaded succesfully') % {:name => @picture.name}
				# Are we using the Flash uploader? Or the plain html file uploader?
				if params[Rails.application.config.session_options[:key]].blank?
					flash[:notice] = @message
					#redirect_to :back
					#TODO temporary workaround; has to be fixed.
					redirect_to admin_pictures_path
				end
			end

			def update
				@size = params[:size] || 'medium'
				@picture = Picture.find(params[:id])
				oldname = @picture.name
				@picture.name = params[:name]
				@picture.save
				@message = _("Image renamed successfully from: '%{from}' to '%{to}'") % {:from => oldname, :to => @picture.name}
			end

			def destroy
				@picture = Picture.find(params[:id])
				name = @picture.name
				@picture.destroy
				flash[:notice] = ( _("Image: '%{name}' deleted successfully") % {:name => name} )
				@redirect_url = admin_pictures_path(:per_page => params[:per_page], :page => params[:page], :query => params[:query])
				render :action => :redirect
			end

			def flush
				Picture.all.each do |picture|
					FileUtils.rm_rf("#{Rails.root}/public/pictures/show/#{picture.id}")
					FileUtils.rm_rf("#{Rails.root}/public/pictures/thumbnails/#{picture.id}")
					expire_page(:controller => '/pictures', :action => 'zoom', :id => picture.id)
				end
				@notice = _('Picture cache flushed')
			end

			def show_in_window
				@picture = Picture.find(params[:id])
				render :layout => false
			end

		private

			def pictures_per_page_for_size(size)
				case size
				when 'small'
					per_page = in_overlay? ? 35 : (per_page_value_for_screen_size * 3.25).floor # 55
				when 'large'
					per_page = in_overlay? ? 4 : (per_page_value_for_screen_size / 2.1).floor # 8
				else
					per_page = in_overlay? ? 12 : (per_page_value_for_screen_size / 0.95).ceil # 18
				end
				return per_page
			end

			def in_overlay?
				!params[:element_id].blank?
			end

			def archive_overlay
				@content = Content.find_by_id(params[:content_id], :select => 'id')
				@element = Element.find_by_id(params[:element_id], :select => 'id')
				@options = hashified_options
				respond_to do |format|
					format.html {
						render :partial => 'archive_overlay'
					}
					format.js {
						render :action => :archive_overlay
					}
				end
			end

		end
	end
end
