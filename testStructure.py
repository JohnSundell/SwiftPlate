
# -*- coding: utf-8 -*-

import sys
import os
from os.path import join, getsize

rootFiles = set(['LICENSE', 'Package.swift', 'README.md', sys.argv[1] + '.podspec'])
configFiles = set([sys.argv[1] + '.plist', sys.argv[1] + 'Tests.plist'])
sourceFiles = set([sys.argv[1]+ '.swift'])
testDirs = set([sys.argv[1] + 'Tests'])

for root, dirs, files in os.walk('.'):
	if root == '.':
		if sys.argv[1] + '.xcodeproj' not in dirs:
			print("xcode project not found")
			exit(1)
		if not rootFiles.issubset(files):
			print("root level files not found")
			exit(1)
	if root == './Configs':
		if not configFiles.issubset(files):
			print("Config files not found")
			exit(1)
	if root == './Sources':
		if not sourceFiles.issubset(files):
			print("Source files not found")
			exit(1)
	if root == './Tests':
		if not testDirs.issubset(dirs):
			print("Test Directories not found")
			exit(1)
print("All tests run successfully ⭐⭐⭐⭐⭐")
exit(0)
