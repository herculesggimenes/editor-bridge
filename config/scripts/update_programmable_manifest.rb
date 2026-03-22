#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open-uri"
require "pathname"
require "time"
require "yaml"

REPO_ROOT = Pathname.new(__dir__).join("../..").expand_path
OUTPUT_PATH = REPO_ROOT.join("Sources/EditorBridgeApp/Resources/default-programmable-files.json")
SOURCE_URL = "https://raw.githubusercontent.com/github-linguist/linguist/main/lib/linguist/languages.yml"

MARKUP_ALLOWLIST = [
  "Astro",
  "CSS",
  "HTML",
  "Handlebars",
  "Jinja",
  "Liquid",
  "MDX",
  "Markdown",
  "Pug",
  "SCSS",
  "Sass",
  "Svelte",
  "Twig",
  "Vue",
  "XML",
  "XSLT"
].freeze

DATA_ALLOWLIST = [
  "HCL",
  "INI",
  "JSON",
  "JSON with Comments",
  "JSON5",
  "TOML",
  "XML",
  "XML Property List",
  "YAML"
].freeze

EXTRA_FILENAMES = [
  ".bazelignore",
  ".bazelrc",
  ".bazelversion",
  ".bash_profile",
  ".bashrc",
  ".editorconfig",
  ".env",
  ".env.development",
  ".env.local",
  ".env.production",
  ".env.test",
  ".gitattributes",
  ".gitignore",
  ".npmrc",
  ".nvmrc",
  ".tmux.conf",
  ".tool-versions",
  ".vimrc",
  ".zprofile",
  ".zshrc",
  "Brewfile",
  "Containerfile",
  "Dockerfile",
  "Justfile",
  "Makefile",
  "Procfile",
  "Tiltfile",
  "Vagrantfile"
].freeze

def include_language?(name, attributes)
  type = attributes["type"]
  return true if type == "programming"
  return true if type == "markup" && MARKUP_ALLOWLIST.include?(name)
  return true if type == "data" && DATA_ALLOWLIST.include?(name)

  false
end

content = URI.open(SOURCE_URL, &:read)
languages = YAML.safe_load(content, aliases: true)

extensions = []
filenames = []

languages.each do |name, attributes|
  next unless include_language?(name, attributes)

  Array(attributes["extensions"]).each do |extension|
    normalized = extension.to_s.strip.downcase
    normalized = normalized.delete_prefix(".")
    extensions << normalized unless normalized.empty?
  end

  Array(attributes["filenames"]).each do |filename|
    normalized = filename.to_s.strip
    filenames << normalized unless normalized.empty?
  end
end

filenames.concat(EXTRA_FILENAMES)

payload = {
  "source" => "github-linguist/linguist languages.yml",
  "source_url" => SOURCE_URL,
  "generated_at" => Time.now.utc.iso8601,
  "extensions" => extensions.uniq.sort,
  "filenames" => filenames.uniq.sort
}

OUTPUT_PATH.dirname.mkpath
OUTPUT_PATH.write(JSON.pretty_generate(payload) + "\n")

puts OUTPUT_PATH
