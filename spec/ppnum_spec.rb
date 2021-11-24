# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../lib/ppnum'

RSpec.describe "ppnum" do
  it "does integers" do
    expect(ppnum(1)).to eq '1'
    expect(ppnum(1000)).to eq '1_000'
  end

  it 'left-pads' do
    expect(ppnum(1, 2)).to eq ' 1'
    expect(ppnum(1000, 8)).to eq '   1_000'
  end

  it 'left-pads as best it can' do
    expect(ppnum(1000, 2)).to eq '1_000'
  end

  it 'does decimals' do
    expect(ppnum(1, 0, 2)).to eq '1.00'
    expect(ppnum(1.678, 0, 2)).to eq '1.68'
  end

  it 'Rounds to correct whole number' do
    expect(ppnum(1000.9, 0, 0)).to eq '1_001'
  end

  it "spaces correctly with decimals" do
    expect(ppnum(1.234, 10, 2)).to eq('      1.23')
  end
end
