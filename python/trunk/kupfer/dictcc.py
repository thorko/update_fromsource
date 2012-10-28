"""
This is a dict.cc search plugin 
"""

__kupfer_name__ = _("dict.cc Search")
__kupfer_sources__ = ()
__kupfer_actions__ = ("DictccSearch",)
__description__ = _("translate your words with dict.cc")
__version__ = "1.0"
__author__ = "thorko <info@thorko.de>"

import urllib

from kupfer.objects import Action, TextLeaf
from kupfer import utils

class DictccSearch (Action):
	def __init__(self):
		Action.__init__(self, _("dict.cc Search"))

	def activate(self, leaf):
		search_url = "http://dict.cc/"
		query_url = search_url + "?" + urllib.urlencode({"s" : leaf.object})
		utils.show_url(query_url)

	def item_types(self):
		yield TextLeaf

	def get_description(self):
		return _("Translate your words with dict.cc")

	def get_icon_name(self):
		return "edit-find"
