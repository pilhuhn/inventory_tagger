FROM ruby:onbuild

ENV HOST="hawkular"
CMD ["./inventory_tagger.rb"]