require 'spec_helper'
require_relative '../helpers/maybe'

describe Monad::DoNotation do
  context "sequencing" do
    def my_monad
      Monad::DoNotation.for(Maybe) do
        Some(4)
        Some(5)
        Some(6)
      end
    end

    it "returns the last Maybe value" do
      expect(my_monad).to eq Some(6)
    end
  end

  context "binding variables" do
    def my_monad
      Monad::DoNotation.for(Maybe) do
        x <- Some(4)
        y <- Some(x + 5)
        Some(x + y)
      end
    end

    it "works" do
      expect(my_monad).to eq Some(13)
    end
  end

  context "return" do
    def my_monad
      Monad::DoNotation.for(Maybe) do
        x <- Some(3)
        return x * 2
      end
    end

    it "wraps the return value in the provided Monad" do
      expect(my_monad).to eq Some(6)
    end
  end

  context "let expression" do
    def my_monad
      Monad::DoNotation.for(Maybe) do
        let x = 1 + 3
        Some(x)
      end
    end

    it "returns Some(4)" do
      expect(my_monad).to eq Some(4)
    end
  end

  context "complex example" do
    def my_monad(optional)
      Monad::DoNotation.for(Maybe) do
        x <- optional
        y <- (if x == "bar"
          None.new
        else
          Some("correct")
        end)
        let z = x.upcase
        case y
        when "correct"
          Some("ignored")
        else
          Some("ignored as well")
        end
        return x + y + z
      end
    end

    it "returns Some when given 'foo'" do
      expect(my_monad(Some("foo"))).to eq Some("foocorrectFOO")
    end

    it "returns None when given 'bar'" do
      expect(my_monad(Some("bar"))).to eq None.new
    end
  end

  context "use blocks within do notation" do
    def my_monad
      Monad::DoNotation.for(Maybe) do
        Some(1).bind do |v|
          Some(v + 1)
        end
      end
    end

    it "doesn't break" do
      expect(my_monad).to eq Some(2)
    end
  end

  context "pass lambda as block" do
    def my_monad(l)
      Monad::DoNotation.for(Maybe, &l)
    end

    it "doesn't break" do
      l = -> {
        Some(1).bind do |v|
          Some(v + 1)
        end
      }
      expect(my_monad(l)).to eq Some(2)
    end
  end

  context "wrapper function around .for" do
    def my_wrapper(&block)
      Monad::DoNotation.for(Maybe, &block)
    end

    def my_monad
      my_wrapper do
        return 2 + 4
      end
    end

    it "works" do
      expect(my_monad).to eq Some(6)
    end
  end
end
