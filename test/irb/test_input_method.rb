# frozen_string_literal: false

require "test/unit"
require "irb"

module TestIRB
  class TestRelineInputMethod < Test::Unit::TestCase
    def setup
      @conf_backup = IRB.conf.dup
      IRB.conf[:LC_MESSAGES] = IRB::Locale.new

      # RelineInputMethod#initialize calls IRB.set_encoding, which mutates standard input/output's encoding
      # so we need to make sure we set them back
      @original_encodings = {
        STDIN => [STDIN.external_encoding, STDIN.internal_encoding],
        STDOUT => [STDOUT.external_encoding, STDOUT.internal_encoding],
        STDERR => [STDERR.external_encoding, STDERR.internal_encoding],
      }
    end

    def teardown
      IRB.conf.replace(@conf_backup)

      @original_encodings.each do |io, (external_encoding, internal_encoding)|
        io.set_encoding(external_encoding, internal_encoding)
      end
    end

    def test_initialization
      IRB::RelineInputMethod.new

      assert_nil Reline.completion_append_character
      assert_equal '', Reline.completer_quote_characters
      assert_equal IRB::InputCompletor::BASIC_WORD_BREAK_CHARACTERS, Reline.basic_word_break_characters
      assert_equal IRB::InputCompletor::CompletionProc, Reline.completion_proc
      assert_equal IRB::InputCompletor::PerfectMatchedProc, Reline.dig_perfect_match_proc
    end

    def test_initialization_without_use_autocomplete
      original_show_doc_proc = Reline.dialog_proc(:show_doc)&.dialog_proc
      empty_proc = Proc.new {}
      Reline.add_dialog_proc(:show_doc, empty_proc)

      IRB.conf[:USE_AUTOCOMPLETE] = false

      IRB::RelineInputMethod.new

      refute Reline.autocompletion
      assert_equal empty_proc, Reline.dialog_proc(:show_doc).dialog_proc
    ensure
      Reline.add_dialog_proc(:show_doc, original_show_doc_proc, Reline::DEFAULT_DIALOG_CONTEXT)
    end

    def test_initialization_with_use_autocomplete
      original_show_doc_proc = Reline.dialog_proc(:show_doc)&.dialog_proc
      empty_proc = Proc.new {}
      Reline.add_dialog_proc(:show_doc, empty_proc)

      IRB.conf[:USE_AUTOCOMPLETE] = true

      IRB::RelineInputMethod.new

      assert Reline.autocompletion
      assert_equal IRB::RelineInputMethod::SHOW_DOC_DIALOG, Reline.dialog_proc(:show_doc).dialog_proc
    ensure
      Reline.add_dialog_proc(:show_doc, original_show_doc_proc, Reline::DEFAULT_DIALOG_CONTEXT)
    end

    def test_initialization_with_use_autocomplete_but_without_rdoc
      original_show_doc_proc = Reline.dialog_proc(:show_doc)&.dialog_proc
      empty_proc = Proc.new {}
      Reline.add_dialog_proc(:show_doc, empty_proc)

      IRB.conf[:USE_AUTOCOMPLETE] = true

      without_rdoc do
        IRB::RelineInputMethod.new
      end

      assert Reline.autocompletion
      # doesn't register show_doc dialog
      assert_equal empty_proc, Reline.dialog_proc(:show_doc).dialog_proc
    ensure
      Reline.add_dialog_proc(:show_doc, original_show_doc_proc, Reline::DEFAULT_DIALOG_CONTEXT)
    end

    def without_rdoc(&block)
      ::Kernel.send(:alias_method, :old_require, :require)

      ::Kernel.define_method(:require) do |name|
        raise LoadError, "cannot load such file -- rdoc (test)" if name == "rdoc"
        original_require(name)
      end

      yield
    ensure
      ::Kernel.send(:alias_method, :require, :old_require)
    end
  end
end
