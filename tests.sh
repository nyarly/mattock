#!/bin/sh -ex

bundle check || bundle install
rake ci
