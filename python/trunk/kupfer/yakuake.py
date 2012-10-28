# -*- coding: UTF-8 -*-
__kupfer_name__ = _("Yakuake Hosts")
__description__ = _("Adds the yakuake hosts found in ~/.yakuakehosts.")
__version__ = "2012-10"
__author__ = "Thorko"

__kupfer_sources__ = ("YakuakeSource", )
__kupfer_actions__ = ("YakuakeConnect", )

import codecs
import os
import string

from kupfer import icons, utils
from kupfer.objects import Action
from kupfer.obj.helplib import FilesystemWatchMixin
from kupfer.obj.grouping import ToplevelGroupingSource
from kupfer.obj.hosts import HOST_NAME_KEY, HostLeaf, HOST_SERVICE_NAME_KEY, \
		HOST_ADDRESS_KEY



class YakuakeLeaf (HostLeaf):
	"""The yakuake host. It only stores the "Host" as it was
	specified in the ssh config.
	"""
	def __init__(self, name):
		slots = {HOST_NAME_KEY: name, HOST_ADDRESS_KEY: name,
				HOST_SERVICE_NAME_KEY: "ssh"}
		HostLeaf.__init__(self, slots, name)

	def get_description(self):
		return _("Yakuake host")

	def get_gicon(self):
		return icons.ComposedIconSmall(self.get_icon_name(), "applications-internet")


class YakuakeConnect (Action):
	"""Used to launch a yakuake connecting to the specified
	yakuake host.
	"""
	def __init__(self):
		Action.__init__(self, name=_("Connect"))

	def activate(self, leaf):
		#utils.spawn_in_terminal(["ssh", leaf[HOST_ADDRESS_KEY]])
		#r = utils.spawn_async(["ykctl", leaf[HOST_ADDRESS_KEY]])
		if utils.spawn_async(['/usr/bin/qdbus', 'org.kde.yakuake', '/yakuake/sessions', 'addSession']):
			pipe = os.popen('/usr/bin/qdbus org.kde.yakuake | /bin/grep Sessions | /usr/bin/cut --fields "3" --delim="/" | /usr/bin/sort -n | /usr/bin/tail -n 1')
			output = pipe.read().splitlines()
			terminalid = 0
			terminalid = int(output[0])-1
			cmd = string.join(['qdbus', 'org.kde.yakuake', '/yakuake/tabs', 'setTabTitle', str(terminalid), leaf[HOST_ADDRESS_KEY].encode()])
			os.system(cmd)
			cmd = string.join(["/usr/bin/qdbus", "org.kde.yakuake", "/yakuake/sessions", "runCommandInTerminal", str(terminalid), "'", "ssh", leaf[HOST_ADDRESS_KEY].encode(), "'"])
			os.system(cmd)
			utils.spawn_async(['qdbus', 'org.kde.yakuake', '/yakuake/window', 'toggleWindowState'])

	def get_description(self):
		return _("Connect to host using yakuake")

	def get_icon_name(self):
		return "network-server"

	def item_types(self):
		yield HostLeaf

	def valid_for_item(self, item):
		return True
	#	if item.check_key(HOST_SERVICE_NAME_KEY):
	#		return item[HOST_SERVICE_NAME_KEY] == 'ssh'
	#	return False


class YakuakeSource (ToplevelGroupingSource, FilesystemWatchMixin):
	"""Reads ~/.yakuakehosts and creates leaves for the hosts found.
	"""
	_yk_home = os.path.expanduser("~/")
	_yk_config_file = ".yakuakehosts"
	_config_path = os.path.join(_yk_home, _yk_config_file)

	def __init__(self, name=_("Yakuake Hosts")):
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
				yield YakuakeLeaf(line)
		except EnvironmentError, exc:
			self.output_error(exc)
		except UnicodeError, exc:
			self.output_error("File %s not in expected encoding (UTF-8)" %
					self._config_path)
			self.output_error(exc)

	def get_description(self):
		return _("yakuake hosts as specified in ~/.yakuakehosts")

	def get_icon_name(self):
		return "applications-internet"

	def provides(self):
		yield YakuakeLeaf

