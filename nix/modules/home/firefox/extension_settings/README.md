# Tutorial - how to set extension settings

This directory contains settings for Firefox extensions.

1. get the extension ID for the extension you want to configure from:
   about:debugging#/runtime/this-firefox

2. get the current settings of the extension from: /home/roey/.mozilla/firefox/<profile>/browser-extension-data/<extension-id>/storage.js

3. copy these settings to [ https://json-to-nix.pages.dev ](this website)

4. get the nix expression and put it in the programs.firefox.profiles.<profile>.extensions.settings.<extension-id>.settings attribute
