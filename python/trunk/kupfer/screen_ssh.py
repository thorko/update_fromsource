# -*- coding: UTF-8 -*-
__kupfer_name__ = _("ScreenSSH Hosts")
__description__ = _("Connects to hosts found in ~/.screenssh and attaches a window to last screen session.")
__version__ = "2012-10"
__author__ = "Thorko"

__kupfer_sources__ = ("ScreenSSHSource", )
__kupfer_actions__ = ("ScreenSSHConnect", )

import codecs
import os
import string
import re

from kupfer import icons, utils, uiutils
from kupfer.objects import Action
from kupfer.obj.helplib import FilesystemWatchMixin
from kupfer.obj.grouping import ToplevelGroupingSource
from kupfer.obj.hosts import HOST_NAME_KEY, HostLeaf, HOST_SERVICE_NAME_KEY, \
		HOST_ADDRESS_KEY

def screen_sessions_infos():
	"""
	Yield tuples of pid, name, time, status
	for running screen sessions
	"""
	regex = re.compile('^There is a screen')
	pipe = os.popen("screen -list")
	output = pipe.read()
	for line in output.splitlines():
		if regex.match(line):
			return 1
	return 0

class ScreenSSHLeaf (HostLeaf):
	"""The screenssh host. It only stores the "Host" as it was
	specified in the ssh config.
	"""
	def __init__(self, name):
		slots = {HOST_NAME_KEY: name, HOST_ADDRESS_KEY: name,
				HOST_SERVICE_NAME_KEY: "ssh"}
		HostLeaf.__init__(self, slots, name)

	def get_description(self):
		return _("ScreenSSH host")

	def get_gicon(self):
		return icons.ComposedIconSmall(self.get_icon_name(), "applications-internet")


class ScreenSSHConnect (Action):
	"""Used to launch a ssh connection to the specified
	host.
	"""
	def __init__(self):
		Action.__init__(self, name=_("Connect"))

	def activate(self, leaf):
		title = leaf[HOST_ADDRESS_KEY].split('.')
		cmd = ""
		# get screen sessions
		r = screen_sessions_infos()
		if r == 0:
			uiutils.show_notification("Sorry", "no screen session found\r\nPlease start one before using this\r\nand do not detach", "network-server", 0)
		else:
			cmd = string.join([cmd, "screen", "-X", "screen;"])
			cmd = string.join([cmd, "screen", "-X", "stuff", "\"ssh", leaf[HOST_ADDRESS_KEY].encode(), "\r\";"]) 
			cmd = string.join([cmd, "sleep", "2;"])
			cmd = string.join([cmd, "screen", "-X", "title", title[0], ";"])
			os.system(cmd)

	def get_description(self):
		utils.spawn_async(cmd)

	def get_description(self):
		return _("Connect to host using ssh")

	def get_icon_name(self):
		return "network-server"

	def item_types(self):
		yield HostLeaf

	def valid_for_item(self, item):
		return True
	#	if item.check_key(HOST_SERVICE_NAME_KEY):
	#		return item[HOST_SERVICE_NAME_KEY] == 'ssh'
	#	return False


class ScreenSSHSource (ToplevelGroupingSource, FilesystemWatchMixin):
	"""Reads ~/.screenssh and creates leaves for the hosts found.
	"""
	_yk_home = os.path.expanduser("~/")
	_yk_config_file = ".screenssh"
	_config_path = os.path.join(_yk_home, _yk_config_file)

	def __init__(self, name=_("ScreenSSH Hosts")):
		ToplevelGroupingSource.__init__(self, name, "hosts")
		self._version = 2

	def initialize(self):
		ToplevelGroupingSource.initialize(self)
		self.monitor_token = self.monitor_directories(self._yk_home)

	def monitor_include_file(self, gfile):
		return gfile and gfile.get_basename() == self._yk_config_file

	def get_items(self):
		try:
			content = codecs.open(self._config_path, "r", "UTF-8").readlines()
			for line in content:
				line = line.strip()
				yield ScreenSSHLeaf(line)
		except EnvironmentError, exc:
			self.output_error(exc)
		except UnicodeError, exc:
			self.output_error("File %s not in expected encoding (UTF-8)" %
					self._config_path)
			self.output_error(exc)

	def get_description(self):
		return _("hosts as specified in ~/.screenssh")

	def get_icon_name(self):
		return "applications-internet"

	def provides(self):
		yield ScreenSSHLeaf

