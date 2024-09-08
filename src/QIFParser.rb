# ' QIFParser class is responsible for parsing QIF files and converting the data into a structured JSON format.
# '
# ' @title QIFParser
# ' @description Parses QIF files and converts the data into JSON format.
# ' @details The QIFParser class provides methods to parse QIF files and convert the data into a structured JSON format.
# ' @export QIFParser
# ' @author [Author Name]
# ' @seealso [Related Functions or Classes]
# ' @examples
# ' # Create a QIFParser object
# ' parser <- QIFParser$new("example.qif")
# ' # Parse the QIF file
# ' parser$parse()
# ' # Convert the parsed data to JSON
# ' json_data <- parser$to_json()
# ' @importFrom jsonlite toJSON
# ' @importFrom jsonlite prettify
# ' @importFrom jsonlite fromJSON
# ' @importFrom jsonlite toJSON
# ' @importFrom jsonlite prettify
# ' @importFrom jsonlite fromJSON

require 'optparse'
require 'json'

# QIFParser class is responsible for parsing QIF files and converting the data into a structured JSON format.
class QIFParser
  def initialize(file_path)
    @file_path = file_path
    @accounts = {}
    @categories = []
    @current_account = nil
    @current_section = nil
  end

  # Parses the QIF file, processing it line by line.
  def parse
    current_entry = {}

    File.foreach(@file_path) do |line|
      line.chomp!

      # Determine the section based on the line prefix
      if line.start_with?('!')
        case line
        when '!Account'
          @current_section = :account
          process_account_section
        when '!Type:Cat'
          @current_section = :category
          process_category_section
        when /^!Type:/
          @current_section = :transaction
          process_transaction_section(line)
        end
      elsif line == '^'
        # Finalize the current entry when encountering a '^' delimiter
        finalize_entry(current_entry)
        current_entry = {}
      else
        # Process a regular line within the current section
        process_line(line, current_entry)
      end
    end
  end

  # Initializes the processing of an account section
  def process_account_section
    @current_account = nil
  end

  # Initializes the processing of a transaction section
  def process_transaction_section(line)
    # Logic specific to the transaction section can be added here if needed.
  end

  # Initializes the processing of a category section
  def process_category_section
    # Logic specific to the category section can be added here if needed.
  end

  # Finalizes and stores the current entry based on the current section
  def finalize_entry(current_entry)
    case @current_section
    when :transaction
      if @current_account
        @accounts[@current_account][:transactions] ||= []
        @accounts[@current_account][:transactions] << current_entry unless current_entry.empty?
      end
    when :category
      @categories << current_entry unless current_entry.empty?
    end
  end

  # Processes a single line of the QIF file, delegating to the appropriate method based on the current section
  def process_line(line, current_entry)
    key = line[0]
    value = line[1..].strip

    case @current_section
    when :transaction
      process_transaction_line(key, value, current_entry)
    when :category
      process_category_line(key, value, current_entry)
    when :account
      process_account_line(key, value)
    end
  end

  # Handles the processing of transaction-specific lines
  def process_transaction_line(key, value, current_entry)
    case key
    when 'D'
      current_entry[:date] = value
    when 'T'
      current_entry[:amount] = value.to_f
    when 'P'
      current_entry[:payee] = value
    when 'M'
      current_entry[:memo] = value
    when 'C'
      current_entry[:cleared_status] = value
    when 'L'
      current_entry[:category] = value
      current_entry[:transaction_type] = 'Transfer' if value.include?('[') && value.include?(']')
    when 'S'
      current_entry[:split_category] = value
    when 'E'
      current_entry[:split_memo] = value
    when '$'
      current_entry[:split_amount] = value.to_f
    end
  end

  def process_category_line(key, value, current_entry)
    # Handles the processing of category-specific lines def process_category_line(key, value, current_entry)
    case key
    when 'N'
      if value.include?(':')
        main_category, sub_category, sub_sub_category = value.split(':', 3)
        current_entry[:name] = main_category
        current_entry[:sub_category] = sub_category unless sub_category.nil?
        current_entry[:sub_sub_category] = sub_sub_category unless sub_sub_category.nil?
      else
        current_entry[:name] = value
      end
    when 'D'
      current_entry[:description] = value
    when 'I'
      current_entry[:income] = true
    when 'E'
      current_entry[:expense] = true
    end
  end

  # Handles the processing of account-specific lines
  def process_account_line(key, value)
    case key
    when 'N'
      @current_account = value
      @accounts[@current_account] ||= {}
    when 'T'
      @accounts[@current_account][:type] = value
    when 'D'
      @accounts[@current_account][:description] = value
    when 'B'
      @accounts[@current_account][:initial_balance] = value.to_f
    end
  end

  # Converts the parsed data into a JSON structure
  def to_json(*_args)
    output = {
      accounts: @accounts,
      categories: @categories
    }
    JSON.pretty_generate(output)
  end
end

# Command-line interface options
options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: qif_parser.rb [options]'

  opts.on('-f', '--file FILE', 'Path to the QIF file to process') do |file|
    options[:file] = file
  end

  opts.on('-o', '--output FILE', 'Path to the output file (optional, JSON format)') do |output|
    options[:output] = output
  end

  opts.on('-h', '--help', 'Displays this help message') do
    puts opts
    exit
  end
end.parse!

# Ensure a file is provided
if options[:file].nil?
  puts 'Please specify a QIF file using the -f option.'
  exit
end

# Parse the QIF file
parser = QIFParser.new(options[:file])
parser.parse

# Handle output
if options[:output]
  if options[:output].end_with?('.json')
    File.open(options[:output], 'w') do |f|
      f.write(parser.to_json)
    end
  else
    puts 'Unsupported output format. Use .json.'
  end
else
  # If no output file is specified, print the JSON to the terminal
  puts parser.to_json
end
