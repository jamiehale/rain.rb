#! /usr/bin/env ruby

require 'digest/sha1'

class HashPath
  
  def initialize(hash)
    @hash = hash
    raise "Invalid hash" if @hash.size != 40
  end
  
  def folder
    @hash[0..1]
  end
  
  def filename
    @hash[2..-1]
  end
  
  def pathname
    "#{folder}/#{filename}"
  end
  
end

class TaskHasher
  
  def initialize
  end
  
  def hash_for(task)
    
  end
  
end

class BlobWriter
  
  def initialize
  end
  
  def write(blob)
    hash_path = HashPath.new(blob.hash)
    Dir.mkdir(hash_path.folder) unless File.directory?(hash_path.folder)
    File.open(hash_path.pathname, 'w') do |f|
      f.write(blob.to_s)
    end
  end
  
end

class BlobReader
  
  def initialize
  end
  
  def read(hash_path)
    File.open(hash_path.pathname, 'r') do |f|
      return f.read
    end
  end
  
end

class BlobDecoder
  
  def initialize(task_decoder = nil)
    @task_decoder = task_decoder || TaskDecoder.new
  end
  
  def decode(blob)
    lines = blob.split("\n")
    raise "Invalid blob" if lines.empty?
    case extract_command(lines[0])
    when 'Task'
      return @task_decoder.decode(lines)
    else
      raise 'Invalid blob command'
    end
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
    @fields.map{|f| "#{f.name}: #{f.value}"}.join("\n") + "\n" + @extra
  end
  
end
  
class TaskReader
  
  def initialize
  end
  
  def read(hash_path)
    t = Task.new
    File.open(hash_path.pathname, 'r') do |f|
      read_fields_into(f, t)
      read_description_into(f, t)
    end
    t
  end
  
  private

    def read_fields_into(f, t)
      while l = f.gets do
        line = l.chomp
        break if line.empty?
        command, details = extract(line)
        case command
        when 'Task'
          t.title = details
        when 'Context'
          t.context = details
        when 'ChildHash'
          t.children << TaskReader.new.read(HashPath.new(details))
        end
      end
    end
    
    def read_description_into(f, t)
      while l = f.gets do
        if t.description.nil?
          t.description = l
        else
          t.description += l
        end
      end
    end
    
    def extract(line)
      command = line.match(/^([^:]+):/)[1]
      details = line[(command.size + 2)..-1]
      [command, details]
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
  
  attr_accessor :parent_hash, :root_hash, :root_task
  
  def initialize
  end
  
  def to_s
    "Commit: #{@root_hash}\n"\
    "Parent: #{@parent_hash}\n"
  end
  
  def hash
    Digest::SHA1.hexdigest(to_s)
  end
  
  def hash_path
    HashPath.new(hash)
  end
  
end

class CommitReader
  
  def initialize
  end

  def read(hash_path)
    c = Commit.new
    File.open(hash_path.pathname, 'r') do |f|
      read_fields_into(f, c)
    end
    c
  end
  
  private

    def read_fields_into(f, c)
      while l = f.gets do
        line = l.chomp
        break if line.empty?
        command, details = extract(line)
        case command
        when 'Commit'
          c.root_task = TaskReader.new.read(HashPath.new(details))
        when 'Parent'
          c.parent_hash = details
        end
      end
    end
    
    def extract(line)
      command = line.match(/^([^:]+):/)[1]
      details = line[(command.size + 2)..-1]
      [command, details]
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


class HeadWriter
  
  def initialize
  end
  
  def write(head)
    File.open('HEAD', 'w') do |f|
      f.puts(head.to_s)
    end
  end
  
end

class HeadReader
  
  def initialize
  end
  
  def read
    return Head.new(nil) unless File.exists?('HEAD')
    File.open('HEAD', 'r') do |f|
      tokens = f.gets.chomp.split(' ')
      raise "Invalid HEAD state" if tokens[0] != 'Head:'
      raise "Invalid HEAD file" if tokens.size != 2
      Head.new(tokens[1])
    end
  end
  
end

head = HeadReader.new.read

#blob_reader = BlobReader.new

#blob_map = {}
#blob_map[head.commit_hash] = BlobReader.new.read(head.commit_hash_path)
#root_task.each_child_hash do |hash|
#  blob_map[hash] = 

commit = CommitReader.new.read(head.commit_hash_path)
puts commit.root_task.to_s

#t.description = "Modified at #{Time.now}"
#BlobWriter.new.write(t)

#c = Commit.new(head.commit_hash, t.hash)
#BlobWriter.new.write(c)

#head.commit_hash = c.hash
#HeadWriter.new.write(head)

