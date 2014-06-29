<<<<<<< HEAD
Data extractor 
=========================

This project is base on the [thingiverse-ruby](https://github.com/makerbot/thingiverse-ruby) project

Requirement : 
 
 * thingiverse access token
 * mongoDB
 
Usage
---


And here's some code!

```ruby
  tv = Thingiverse::Connection.new
  tv.access_token = 'your access token here'
  
  service = ThingsService.new(tv)
  
  tag = tv.tags().find("customizer")
  service.insertThingsByTag(tag)
```
=======
thingiverse-data-extractor
==========================
>>>>>>> eb80091936ae413028a44c9b2b0cbeed78cd94fa
