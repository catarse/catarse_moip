# CatarseMoip [![Build Status](https://travis-ci.org/catarse/catarse_moip.png)](https://travis-ci.org/catarse/catarse_moip) 

Catarse moip integration with [Catarse](http://github.com/catarse/catarse) crowdfunding platform

## Installation

Add this lines to your Catarse application's Gemfile:

    gem 'catarse_moip'

And then execute:

    $ bundle

## Usage

Configure the routes for your Catarse application. Add the following lines in the routes file (config/routes.rb):

    mount CatarseMoip::Engine => "/", :as => "catarse_moip"

## Rails 3.2.x and Rails 4 support

If you are using the Rails 3.2.x on Catarse's code, you can use the version `1.0.0`.

For Rails 4 support use the `2.0.0` version.

### Configurations

Create this configurations into Catarse database:

    moip_uri, moip_token and moip_key

In Rails console, run this:

    Configuration.create!(name: "moip_uri", value: "https://desenvolvedor.moip.com.br/sandbox")
    Configuration.create!(name: "moip_token", value: "TOKEN")
    Configuration.create!(name: "moip_key", value: "KEY")

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


This project rocks and uses MIT-LICENSE.

