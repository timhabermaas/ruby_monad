require "monad/version"
require "method_source"
require "ruby_parser"
require "ruby2ruby"

module Monad
  module Syntax
    module Do
      def self.using(monad_type, &block)
        Monad::Syntax::Do::Notation.new(monad_type).run(&block)
      end

      class Notation
        Assignment = Struct.new(:lhs, :rhs)
        SingleStatement = Struct.new(:rhs)
        LetStatement = Struct.new(:lhs, :rhs)
        Unit = Struct.new(:rhs)

        def initialize(monad_type)
          @monad_type = monad_type
        end

        def run(&block)
          original_binding = block.binding
          parsed_source = RubyParser.new.parse(block.source)
          inner_block = find_block(parsed_source)
          rows = iter_to_block_commands(inner_block)
          execute(@monad_type, rows.map { |r| parse_row(r) }, original_binding)
        end

        private

        def find_block(sexp)
          # Special case if block has been assigned to variable:
          if sexp.is_a?(Array) && sexp.first == :lasgn
            return sexp.last
          end
          looop = lambda do |syntax|
            if syntax.is_a?(Array) && syntax.first == :iter && syntax[1].is_a?(Array) && syntax[1].first == :call
              return syntax
            elsif syntax.is_a?(Array)
              syntax.find do |s|
                looop.call(s)
              end
            else
              nil
            end
          end
          looop.call(sexp)
        end

        # Single lines are not wrapped in a :block,
        # normalize it.
        def iter_to_block_commands(iter)
          if iter[3].is_a?(Array) && iter[3].first == :block
            iter[3][1..-1]
          else
            [iter[3]]
          end
        end

        def execute(monad_type, rows, binding)
          row = rows.first
          if rows.size == 1
            if row.is_a? Unit
              return monad_type.return(binding.eval(row.rhs))
            else
              return binding.eval(row.rhs)
            end
          end
          case row
          when Assignment
            binding.eval(row.rhs).bind do |v|
              binding.local_variable_set(row.lhs, v)
              execute(monad_type, rows[1..-1], binding)
            end
          when SingleStatement
            binding.eval(row.rhs).bind do |_|
              execute(monad_type, rows[1..-1], binding)
            end
          when LetStatement
            value = binding.eval(row.rhs)
            binding.local_variable_set(row.lhs, value)
            execute(monad_type, rows[1..-1], binding)
          when Unit
            monad_type.return(binding.eval(row.rhs))
          end
        end

        def parse_row(row)
          # s(:call, nil, :let, s(:lasgn, :x, s(:lit, 1)))
          if is_let_statement(row)
            LetStatement.new(row[3][1], Ruby2Ruby.new.process(row[3].last))
          elsif is_assignment(row)
            Assignment.new(row[1].last, Ruby2Ruby.new.process(row.last[1]))
          elsif is_return(row)
            Unit.new(Ruby2Ruby.new.process(row.last))
          else
            SingleStatement.new(Ruby2Ruby.new.process(row))
          end
        end

        def is_return(row)
          row.size == 2 &&
            row.first == :return
        end

        def is_single_statement(row)
          row.first == :call
        end

        def is_let_statement(row)
          row.first == :call && row[2] == :let
        end

        def is_assignment(row)
          row.size == 4 &&
            row.first == :call &&
            row[2] == :< &&
            is_unary_minus(row[3]) &&
            is_single_variable(row[1])
        end

        def is_unary_minus(x)
          x.size == 3 &&
            x.first == :call &&
            x.last == :-@
        end

        def is_single_variable(x)
          x.size == 3 &&
            x.first == :call &&
            x[1] == nil
        end
      end
    end
  end
end
