# frozen_string_literal: true

class Nitl < Formula
  desc "Human-In-The-Loop AI Factory for GitHub issues"
  homepage "https://github.com/yourusername/nitl"
  url "https://github.com/yourusername/nitl/archive/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on "ruby" => :recommended
  depends_on "gh"
  depends_on "jq"
  depends_on "max-sixty/worktrunk/wt"

  def install
    # Install executable
    bin.install "bin/nitl"

    # Install library files
    lib.install Dir["lib/**/*"]
  end

  test do
    system "#{bin}/nitl", "--version"
  end
end
