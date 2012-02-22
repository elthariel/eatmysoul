##
## Makefile
## Login : <elthariel@steel.newbacchus.org>
## Started on  Wed Feb 22 11:51:24 2012 elthariel
## $Id$
##
## Author(s):
##  - elthariel <>
##
## Copyright (C) 2012 elthariel
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
##

all: eatmysoul

eatmysoul:
	echo "Ruby program, nothing to build"

intall:
	install -d $(DESTDIR)/usr/bin
	install -m 755 eatmysoul $(DESTDIR)/usr/bin

clean:
	echo "Nothing to clean"

debian:
	git-buildpackage  --git-upstream-tree=branch --git-ingore-new
