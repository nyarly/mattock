#!/bin/sh -ex

bundle check || bundle install
bundle exec rake ci
