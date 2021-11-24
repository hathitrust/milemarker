# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Milemarker do
  it "has a version number" do
    expect(Milemarker::VERSION).not_to be nil
  end

  it "triggers on on_batch" do
    triggers = []
    mm = basic_mm(5, 12) { |i, _mm| triggers << i }
    expect(triggers).to contain_exactly(5, 10)
  end

  it "time marches forward" do
    times = []
    mm = basic_mm(5, 12) { |_i, mm| times << mm.total_seconds_so_far }
    expect(times.size).to eq(2)
    expect(times.last).to be > times.first
  end

  it "batch time is reasonable" do
    mm = Milemarker.new(batch_size: 5)
    times = []
    (1..12).each do |i|
      sleep(1) if i == 8
      mm.increment_and_on_batch { |mm| times << mm.last_batch_seconds }
    end
    expect(times.first + 1).to be_within(0.01).of(times.last)
  end

  it "outputs batch log lines as expected" do
    mm = Milemarker.new(batch_size: 5)
    mm.create_logger!(STDOUT)
    r = /INFO.*?5\.\s+This batch\s+5.*?INFO.*?10\.\s+This batch\s+5/m
    expect { (1..12).each { |_i| mm.increment_and_log_batch_line } }.to output(r).to_stdout_from_any_process
  end

  it "correctly counts the final, incomplete batch" do
    mm = basic_mm(5, 12) {}
    expect(mm.final_batch_size).to eq(2)
  end

  it "does ok if count % batch == 0" do
    mm = basic_mm(5, 15) {}
    expect(mm.final_batch_size).to eq(0)
  end

  it "puts out a reasonable final batch log line" do
    mm = basic_mm(5, 12) {}
    mm.create_logger!(STDOUT)
    r = / FINISHED\.\s+12 total records/
    expect { mm.log_final_line }.to output(r).to_stdout_from_any_process
  end
end
