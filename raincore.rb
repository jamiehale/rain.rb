#! /usr/bin/env ruby

require 'digest/sha1'

class Configuration

  attr_accessor :rain_path

  def initialize
    @rain_path = '.'
  end

end

class HashPath
  
  def initialize(hash)
    @hash = hash
    raise "Invalid hash" if @hash.size != 40
  end
  
  def path
    @hash[0..1]
  end
  
  def filename
    @hash[2..-1]
  end
  
  def pathname
    "#{path}/#{filename}"
  end
  
end

class Field
  
  attr_accessor :name, :value
  
  def initialize(name, value)
    @name = name
    @value = value
  end
  
  def to_s
    "#{@name}: #{@value}"
  end
  
end

class FieldDumper
  
  def initialize
    @fields = []
  end
  
  def field(name, value)
    @fields << Field.new(name, value)
  end
  
  def extra(value)
    @extra = value
  end

  def to_s
    @fields.map{|f| "#{f.name}: #{f.value}"}.join("\n") + "\n" + @extra.to_s
  end
  
end
  
class Task
  
  attr_accessor :title, :context, :description, :children
  
  def initialize
    @children = []
  end
  
  def to_s
    d = FieldDumper.new
    d.field "Task", title
    d.field "Context", context
    d.extra description
    d.to_s
  end
  
  def hash
    Digest::SHA1.hexdigest(to_s)
  end
  
  def hash_path
    HashPath.new(hash)
  end
  
end

class Commit

  attr_accessor :world, :parent

  def initialize
  end

  def to_s
    d = FieldDumper.new
    d.field "Commit", world
    d.field "Parent", parent
    d.to_s
  end

  def hash
    Digest::SHA1.hexdigest(to_s)
  end

  def hash_path
    HashPath.new(hash)
  end

end

class Head
  
  attr_accessor :commit_hash
  
  def initialize(commit_hash)
    @commit_hash = commit_hash
  end
  
  def to_s
    "Head: #{@commit_hash}\n"
  end
  
  def commit_hash_path
    HashPath.new(@commit_hash)
  end
  
end

class HeadReader
  
  def initialize(configuration = nil)
    @configuration = configuration || Configuration.new
  end
  
  def read
    return Head.new(nil) unless File.exists?(head_path)
    File.open(head_path, 'r') do |f|
      tokens = f.gets.chomp.split(' ')
      raise "Invalid HEAD state" if tokens[0] != 'Head:'
      raise "Invalid HEAD file" if tokens.size != 2
      Head.new(tokens[1])
    end
  end

  private

    def head_path
      "#{@configuration.rain_path}/refs/HEAD"
    end
  
end

class UpdateHeadStep

  def initialize(head, previous_head, configuration = nil)
    @head = head
    @previous_head = previous_head
    @configuration = configuration || Configuration.new
  end

  def commit
    File.open(head_path, 'w') do |f|
      f.write(@head.to_s)
    end
  end

  def rollback
    File.open(head_path, 'w') do |f|
      f.write(@previous_head.to_s)
    end
  end

  private

    def head_path
      "#{@configuration.rain_path}/refs/HEAD"
    end

end

class CreateBlobStep

  def initialize(blob, configuration = nil)
    @blob = blob
    @configuration = configuration || Configuration.new
  end

  def commit
    Dir.mkdir(path_to_blob) unless File.directory?(path_to_blob)
    File.open(full_blob_path, 'w') do |f|
      f.write(@blob.to_s)
    end
  end

  def rollback
    File.delete(full_blob_path)
    if (Dir.entries(path_to_blob) - %w{ . .. }).empty?
      File.rmdir(path_to_blob)
    end
  end

  private

    def path_to_blob
      "#{@configuration.rain_path}/#{@blob.hash_path.path}"
    end

    def full_blob_path
      "#{path_to_blob}/#{@blob.hash_path.filename}"
    end

end

class Transaction

  def initialize
    @steps = []
  end

  def add(step)
    @steps << step
  end

  def commit
    committed = []
    begin
      @steps.each do |step|
        step.commit
        committed << step
      end
    rescue Exception => e
      raise e
      begin
        committed.reverse.each do |step|
          step.rollback
        end
      rescue
        raise "Error while rolling back"
      end
    end
  end

end

configuration = Configuration.new
configuration.rain_path = 'objects'

head = HeadReader.new.read

task1 = Task.new
task1.title = 'Do something'
task1.context = '@home'

commit = Commit.new
commit.world = task1.hash

new_head = head.clone
new_head.commit_hash = commit.hash

t = Transaction.new
t.add(CreateBlobStep.new(task1, configuration))
t.add(CreateBlobStep.new(commit, configuration))
t.add(UpdateHeadStep.new(new_head, head, configuration))
t.commit

