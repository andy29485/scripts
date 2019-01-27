#!/usr/bin/env python3

import os
import re
import sys
import copy
import glob
import time
import logging
import pyvgmdb
try:
  import gnureadline as readline
except:
  import readline
import requests
import tempfile
from natsort import natsorted
from mutagen.flac import FLAC
from mutagen.flac import Picture as FlacPic
from mutagen.easyid3 import EasyID3
from mutagen.id3 import APIC, TIT2
from unidecode import unidecode

#import pdb
#import pprint ; pp = pprint.PrettyPrinter(indent=2)

EasyID3.RegisterTextKey('comment', 'COMM')

pyvgmdb.logging.getLogger().setLevel(logging.ERROR)

pats0 = [
  (re.compile('、\\s*'), ', '),
  (re.compile('！'),      '!'),
  (re.compile('＆'),      '&'),
  (re.compile('…'),     '...'),
  (re.compile('～'),      '~'),
  (re.compile('’'),       "'")
]

pats1 = [
  (
   re.compile(
    r'\s+[<\[\(-](orig)?(inal)?\s*(off vocals?|instr?(umental)?|kara(oke)?)(\s+ver)?(sion)?\.?[\]\)>-]',
    re.I
   ), ' -instrumental-'
  ),
  (re.compile('\\s+-$'), '-'),
  (re.compile('[\"\'~\\[\\]\\(\\)=\\+\\*<>:]'), '-'),
  (re.compile(r'[^\.A-Za-z0-9 -]'),             ' '),
  (re.compile(r'\s+'),                          ' '),
  (re.compile('\\s+-$'),                        '-'),
  (re.compile(r'\s*\.*(\.[a-z]{2,5})$', re.I),  r'\1')
]

genre_reps = {
  'Talk'      : 'Drama',
  'Animation' : 'Anime',
  'pop'       : '',
  'pop rock'  : '',
  'rock'      : 'Rock',
  'J-pop'     : 'JPop'
}

artist_reps = {
  (re.compile('.*MEIKO.*'),            'メイコ'),
  (re.compile('.*GUMI.*'),               'グミ'),
  (re.compile('.*Megpoid.*'),    'メグッポイド'),
  (re.compile('.*KAITO.*'),            'カイト'),
  (re.compile('.*Gackpoid.*'),   'がくっぽいど'),
  (re.compile('^(イア,?\\s+)?IA.*$'),    'イア'),
  (re.compile('.*Camui Gackpo.*'), '神威がくぽ')
}

char_reps = {
  'Hazime': 'Hajime',
  'Iizima': 'Iijima',
}

default = {
  'album_name_orig'  : '',
  'album_name_latin' : '',
  'source'           : 'none',
  'url'              : '',
  'cover'            : '',
  'thumb'            : '',
  'notes'            : '',
  'date'             : '',
  'genres'           : [],
  'discs'            : [],
  'artists'          : []
}

charnames = {}

def read(prompt, default=''):
  prompt = '\r'+prompt
  def insert_default():
    readline.insert_text(default)
    readline.redisplay()
  while True:
    try:
      text = input(prompt)
      readline.set_pre_input_hook(None)
      return text or default
    except EOFError:
      readline.set_pre_input_hook(insert_default)

def to_gen(func, *args, **kwargs):
  try:
    for elem in func(*args, **kwargs):
      yield elem
  except:
    pass

def join_gens(*gens):
  for gen in gens:
    for elem in gen:
      yield elem

def get_char_name(search):
  for pat,rep in char_reps.items():
    search = search.replace(pat, rep)

  global charnames
  if charnames.get(search):
    return charnames.get(search)

  for i in range(3):
    r = requests.get(f'https://myanimelist.net/character.php?q={search}', timeout=2)
    if r.status_code == 200:
      break
    else:
      time.sleep(1.2)
  if not r or r.status_code != 200:
    return search
  r   = re.findall('<tr>.*?href="([^"]*?)".*?</tr>', str(r.content))
  url = r[0]
  if 'http' not in url:
    url = 'https://myanimelist.net/'+url

  for i in range(4):
    r = requests.get(url)
    if r.status_code == 200:
      break
    else:
      time.sleep(1.6)
  if not r or r.status_code != 200:
    return search

  r = re.search('<div[^<]*?rmal_hea[^<]*?<span[^<]*?<small>\(?([^<]*?)\)?</',
    r.text
  )

  name = r.group(1) if r else search
  charnames[search] = name
  return name

def search_vocadb(terms, domain='https://vocadb.net/'):
  search = requests.get(f'{domain}/api/albums',
                        params={'query':terms, 'preferAccurateMatches':'true'}
  )
  for item in search.json().get('items', []):
    item['vocadb'] = True
    yield item

def get_info(item):
  if type(item) == pyvgmdb.VGMdbProductSummary:
    return get_info_vgmdb(item.id)
  elif type(item) == dict and item.get('vocadb', False):
    return get_info_vocadb(item.get('id'))
  return None

def get_info_vocadb(album_id, domain='https://vocadb.net/'):
  domain = domain.lower()
  params = {'fields'    :'Tracks,mainPicture,Tags,Description,Artists',
            'songFields':'Artists',
            'lang'      :'Romaji'
  }
  album  = f'{domain}/api/albums/{album_id}'
  album  = requests.get(album, params=params).json()
  info   = {}
  tmp    = None
  date   = {'year':1970,'month':1,'day':0}
  date.update(album.get('releaseDate', {}))

  info['album_name_orig']  = ''
  info['album_name_latin'] = ''
  info['source']           = 'vocadb'
  info['url']              = f'{domain}/Al/{album_id}'
  info['cover']            = f'{domain}/Album/CoverPicture/{album_id}?v=3'
  info['thumb']            = album['mainPicture']['urlThumb']
  info['notes']            = album.get('description', '')
  info['date']             = '{year:04}-{month:02}-{day:02}'.format(**date)
  info['genres']           = ['Utaite'] if 'tai' in domain else ['Vocaloid']
  info['discs']            = []
  info['artists']          = []

  tmp     = album.get('defaultName', '').strip()
  for pat, rep in pats0:
    tmp   = pat.sub(rep, tmp)
  info['album_name_orig'] = tmp.strip()

  tmp     = unidecode(album.get('name', '').strip())
  for pat, rep in pats1:
    tmp   = pat.sub(rep, tmp)
  info['album_name_latin'] = tmp.strip()

  for tag in album['tags']:
    tag = tag['tag']['name'].lower()
    for pat,rep in genre_reps.items():
      tag = tag.replace(pat, rep)
    if tag and tag not in info['genres']:
      info['genres'].append(tag)

  for artist in album['artists']:
    cat = artist.get('categories', '')
    try:
      if not artist.get('defaultName') or not artist.get('categories', ''):
        artist = artist.get('artist', artist)
        artist = requests.get(f'{domain}/api/artists/{artist["id"]}')
        artist = artist.json()
      if artist.get('categories', cat) == 'Vocalist':
        tmp = artist.get('defaultName').strip()
        for pat, rep in artist_reps:
          tmp = pat.sub(rep, tmp)
        if tmp not in info['artists']:
          info['artists'].append(tmp)
    except:
      pass

  tracks    = album.get('tracks', [])
  disc_nums = sorted(set([t.get('discNumber',1) for t in tracks]))
  discs     = [
              sorted([t for t in tracks if t.get('discNumber',1) == num],
                     key = lambda x: x.get('trackNumber',1)
              ) for num in disc_nums
  ]
  for disc,num in zip(discs,disc_nums):
    d = []
    for track in disc:
      url = ''
      #asaik vocadb does not have album covers
      #for cover in album.covers:
      #  name = cover.get('name', '')
      #  if is_disc(name) and (num==1 or str(num) in name):
      #    url = cover.get('full', '')
      #    break
      name = track.get('song', {}).get('defaultName', '')
      for pat, rep in pats0:
        name  = pat.sub(rep, name)

      tmp     = unidecode(track.get('song', {}).get('name', ''))
      for pat, rep in pats1:
        tmp   = pat.sub(rep, tmp)
      name_l  = tmp
      artists = []
      for artist in track['song'].get('artists', []):
         if artist.get('categories', '') == 'Vocalist':
           artist = artist.get('artist', artist)
           tmp = artist.get('additionalNames', artist.get('name', ''))
           for pat, rep in artist_reps:
             tmp = pat.sub(rep, tmp)
           if tmp not in artists:
             artists.append(tmp)
      d.append({'name':name, 'name_lat':name_l, 'artists':artists})
    info['discs'].append({'cover':url, 'tracks':d})

  return info

def get_info_vgmdb(album_id):
  album = pyvgmdb.get_album(album_id)
  info  = {}
  tmp   = None

  info['album_name_orig']  = ''
  info['album_name_latin'] = ''
  info['source']           = 'vgmdb'
  info['url']              = 'http://vgmdb.net/{}'.format(album.link)
  info['cover']            = album.picture_full  or album.picture_small
  info['thumb']            = album.picture_small or album.picture_thumb
  info['notes']            = album.notes
  info['date']             = album.release_date
  info['genres']           = []
  info['discs']            = []
  info['artists']          = []

  for key in ('ja', 'ja-latn', 'en'):
    tmp = album.names.get(key, '').rpartition(' / ')[0]
    if tmp:
      break
  else:
    tmp   = album.name
  for pat, rep in pats0:
    tmp   = pat.sub(rep, tmp)
  info['album_name_orig'] = tmp.strip()

  for key in ('ja-latn', 'en'):
    tmp = album.names.get(key, '').rpartition(' / ')[0]
    if tmp:
      break
  else:
    tmp   = album.name
  tmp     = unidecode(tmp)
  for pat, rep in pats1:
    tmp   = pat.sub(rep, tmp)
  info['album_name_latin'] = tmp.strip()

  characters = re.findall(r'(?:is|by|formed|[:,;]|and)\s+(([\w& ]+?) +\(CV[:.]?\s*([& \w]+)\))',
                          info['notes']
  )
  for item in characters:
    if '&' in item[0]:
      cnames = re.split('\\s*&\\s*', item[1])
      anames = re.split('\\s*&\\s*', item[2])
      tmp = []
      for c,a in zip(cnames, anames):
        characters.append([f'{c} (CV: {a})', c, a])
        tmp.append(f'{c} (CV: {a})')
      characters.remove(item)
      info['notes'] = info['notes'].replace(item[0], '; '.join(tmp))
  characters = {i[2]:(i[1], i[0]) for i in characters}

  for artist in album.performers:
    for key in ('ja', 'en'):
      tmp = artist.names.get(key, '')
      if tmp:
        en_name = artist.names.get('en', '')
        name = characters.get(en_name)
        if name:
          n = get_char_name(name[0])
        if name and n:
          tmp = f'{n} (CV: {tmp})'
          info['notes'] = info['notes'].replace(name[1], tmp)
        else:
          info['notes'] = info['notes'].replace(en_name, tmp)
        break
    else:
      tmp = list(artist.names.values() or ['Unknown'])[0]
    for pat, rep in artist_reps:
      tmp = pat.sub(rep, tmp)
    if tmp not in info['artists']:
      info['artists'].append(tmp)

  for genre in album.categories:
    for pat,rep in genre_reps.items():
      genre = genre.replace(pat, rep)
    if tmp not in info['genres']:
      info['genres'].append(genre)

  discs_info = {int(i[1]): i[2]
                for i in re.finditer('DISC (\d+)(.*?)(?=DISC|\n\n\n|$)',
                                     info['notes'], re.S
                )
  }

  for num,disc in enumerate(album.discs, 1):
    d     = []
    url   = ''
    dinfo = discs_info.get(num, info['notes'])
    tracks_info = {int(i[1]): i[2]
                 for i in re.finditer('M-(\d\d)(.*?)(?=M-|\n\n|$)',dinfo,re.S)
    }

    for cover in album.covers:
      name = cover.get('name', '')
      if is_disc(name) and (num==1 or str(num) in name):
        url = cover.get('full', '')
        break
    for track_num,track in enumerate(disc.get('tracks', [])):
      track_info = tracks_info.get(track_num, '')
      for key in ('Japanese', 'Romaji', 'English'):
        tmp = track.get('names', {}).get(key, '')
        if tmp:
          break
      else:
        tmp = list(track.get('names', {1:'Unknown'}).values())[0]
      for pat, rep in pats0:
        tmp   = pat.sub(rep, tmp)
      name = tmp

      for key in ('Romaji', 'English'):
        tmp = track.get('names', {}).get(key, '')
        if tmp:
          break
      else:
        tmp   = ''
      tmp     = unidecode(tmp)
      for pat, rep in pats1:
        tmp   = pat.sub(rep, tmp)
      name_l  = tmp

      a = []
      for artist in info['artists']:
        if artist in track_info and artist not in a:
          a.append(artist)

      d.append({'name':name, 'name_lat':name_l, 'artists':a})
    info['discs'].append({'cover':url, 'tracks':d})

  return info

def pict_test(audio):
  try:
    x = audio.pictures
    if x:
      return True
  except Exception:
    pass
  if 'covr' in audio or 'APIC:' in audio:
    return True
  return False

def add_pic(obj, path):
  if pict_test(obj): #art is already there
    return
  mimetype = 'image/jpeg'
  if type(path) == str:
    with open(path, 'rb') as f:
      imagedata = f.read()
    if path.endswith('png'):
       mimetype = 'image/png'
    else:
       mimetype = 'image/jpeg'
  else:
    imagedata = path

  if type(obj) == EasyID3:
    id3 = obj._EasyID3__id3
    id3.add(APIC(3, mimetype, 3, 'Front cover', imagedata))
    id3.add(TIT2(encoding=3, text='title'))
    id3.save(v2_version=3)
  elif type(obj) == FLAC:
    image = FlacPic()
    image.type = 3
    image.desc = 'front cover'
    image.data = imagedata
    obj.add_picture(image)

def is_disc(dirname):
  if type(dirname) == list:
    for name in dirname:
      if is_disc(name):
        return True
    else:
      return False
  if '.' in dirname:
    return False
  name = os.path.basename(dirname).lower()
  return name.startswith('cd') or 'disk' in name or 'disc' in name

def open_tags(filename):
  if filename.endswith('flac'):
    return FLAC(filename)
  else:
    return EasyID3(filename)

def save_image(url, dirname):
  if not url:
    return ''

  if is_disc(dirname):
    filename = 'disc'
  else:
    filename = 'folder'
  ext = re.search(r'\.[^\.]{2,4}$', url)
  ext = ext.group(0).replace('jpeg', 'jpg') if ext else '.jpg'

  filename = os.path.join(dirname, filename+ext)
  if os.path.exists(filename):
    return

  r = requests.get(url)
  with open(filename, 'wb') as f:
    f.write(r.content)

  if not ext:
    ext = filetype.guess_type(filename)
    if ext:
      os.rename(filename, '{}.{}'.format(filename, ext))

  return filename

def search_album(search):
  while True:
    items = []
    index = 0
    if re.match('^\\d+$', search):
      try:
        info = get_info_vgmdb(int(search))
        if(info):
          items.append(info)
          print(f"{index} - {info['album_name_orig']} - {info['url']}")
          index += 1
      except:
        #raise
        pass
      try:
        info = get_info_vocadb(search)
        if(info):
          items.append(info)
          print(f"{index} - {info['album_name_orig']} - {info['url']}")
          index += 1
      except:
        #raise
        pass
      try:
        info = get_info_vocadb(search, 'http://utaitedb.net/')
        if(info):
          items.append(info)
          print(f"{index} - {info['album_name_orig']} - {info['url']}")
          index += 1
      except:
        pass #raise
    gen = join_gens(to_gen(pyvgmdb.search_albums, search),
           search_vocadb(search), search_vocadb(search,'http://utaitedb.net/')
    )
    for item in gen:
      try:
        info = get_info(item)
      except:
        info = None
      if info:
        items.append(info)
        print(f"{index} - {info['album_name_orig']} - {info['url']}")
        index += 1
        if index >= 10:
          break
    while True:
      search = read('enter index or new search terms [0]("-" for manual): ','0')
      if not search:
        if not items:
          print('enter diffrent search terms please')
          continue
        return items[0]
      elif search == '-':
        return copy.deepcopy(default)
      elif re.match('^\\d$', search):
        index = int(search)
        if index >= len(items):
          continue
        return items[index]
      else:
        break

def sort_music_items(dirname, files):
  items = {}
  if is_disc(files):
    index = 0
    for disc in files:
      discpath = os.path.join(dirname, disc)
      if is_disc(disc):
        index += 1
        tmp = []
        for item in natsorted(os.listdir(discpath)):
          if item.rpartition('.')[2] in ('mp3', 'flac'):
            tmp.append(os.path.join(discpath, item))
        items[(index, discpath)] = tmp
  else:
    items[(1, dirname)] = []
    for item in files:
      if item.rpartition('.')[2] in ('mp3', 'flac'):
        items[(1, dirname)].append(os.path.join(dirname,item))
  return items

def get_album_info(dirname, items):
  #pdb.set_trace()
  tmp_item   = open_tags(list(items.values())[0][0])
  album_name = tmp_item.get('album', [dirname])[0]
  album      = search_album(album_name)
  if not album.get('album_name_orig'):
    album['album_name_orig'] = album_name
  if not album.get('album_name_latin').strip():
    name_lat = os.path.basename(os.path.realpath(dirname))
    name_lat = unidecode(name_lat)
    for pat, rep in pats1:
      name_lat = pat.sub(rep, name_lat)
    album['album_name_latin'] = name_lat.strip()
  if not album.get('genres'):
    album['genres'] = tmp_item.get('genre', [])
  if not album.get('artists'):
    album['artists'] = tmp_item.get('albumartist', tmp_item.get('artist', []))
  if not album.get('date'):
    album['date'] = tmp_item.get('date', [''])[0]
  return album

def user_modify_album(album):
  print('\n\nModify album info(blank = default):')
  keys = ['Original Name', 'Dirname', 'Artists', 'Cover', 'Date', 'Genres']
  index = 0
  new = ''
  while index < len(keys):
    key = keys[index].replace('Dirname', 'album_name_latin') \
                     .replace('Original Name', 'album_name_orig').lower()
    val = album.get(key, '')
    if type(album[key]) == list:
      val = '; '.join(val)
    new = read(f"{keys[index]} [{val}]: ", val).strip()
    if new == '^':
      index -= 1
      continue
    if new:
      if type(album[key]) == list:
        new = re.split(r'\s*;\s*', new)
      album[key] = new
    index += 1
  return album

def save_song(f, info):
  if type(f) == str:
    f = open_tags(f)

  f['title']               = info['title']
  f['album']               = info['album_name_orig'].strip()
  f['date']                = info.get('date',f.get('date',[''])[0]).strip()
  f['artist']              = info['artist']
  f['albumartist']         = info.get('album_artists', '').strip()
  f['genre']               = info['genre']
  f['comment']             = info['comment']
  try:
    f['tracktotal']        = str(info['num_songs'])
    f['tracknumber']       = str(info['index'])
  except:
    f['tracknumber']       = f'{info["index"]:02}/{info["num_songs"]:02}'
  try:
    f['ctdbdiscconfidence']= f'{info["disc_num"]:02}/{info["num_discs"]:02}'
  except:
    f['discnumber']        = f'{info["disc_num"]:02}/{info["num_discs"]:02}'
  f.save()

def process_song(filename, cover_data=None, album={}, info={}, discpath=None):
  f = open_tags(filename)

  if not discpath:
    discpath = os.path.dirname(os.path.realpath(filename))

  if cover_data:
    add_pic(f, cover_data)

  ext = filename.rpartition('.')[2]

  title    = (info.get('name', ''.join(f.get('title', [])))).strip()
  name_lat = re.search(r'\d\d[ _\.-]*([^/]*)\.', os.path.basename(filename)) or ''
  if name_lat:
    name_lat = unidecode(name_lat.group(1))
    for pat, rep in pats1:
      name_lat= pat.sub(rep, name_lat)
  name_lat = info.get('name_lat', name_lat).strip()
  artists  = '; '.join(album.get('artists') or f.get('artist', []))
  genres   = '; '.join(album.get('genres')  or f.get('genre',  []))
  comment  = ''

  if type(f) == EasyID3:
    id3 = f._EasyID3__id3
    if 'COMM::XXX' in id3:
      k = 'COMM::XXX'
    else:
      k = [k for k in id3.keys() if 'COMM' in k] or ['COMM']
      k = k[0]
    if k in id3:
      comment = id3.get(k).text[0]
  else:
    comment = f.get('comment', [''])[0]

  tmp = os.path.basename(filename)
  tmp = re.search(r'^(\d+[ _\.-]+\s*)?(.*?)(\..{2,5})?$', tmp).group(2)
  tmp = unidecode(tmp)
  for pat, rep in pats1:
    tmp = pat.sub(rep, tmp)
  name_lat = name_lat or tmp

  info = {
   'title'      : title,
   'title latin': name_lat,
   'artist'     : '; '.join(info.get('artists',f.get('artist')or[]))or artists,
   'genre'      : genres,
   'comment'    : comment,
   'index'      : info.get('index',     1),
   'num_songs'  : info.get('num_songs', 1),
   'disc_num'   : info.get('disc_num',  1),
   'num_discs'  : info.get('num_discs', 1)
  }

  print(
  '\n\nTrack {disc_num:02}/{num_discs:02} - {index:02}/{num_songs:02}:'.format(
    **info
  ))

  keys = ('Title', 'Title Latin', 'Artist', 'Genre', 'Comment')
  item_index = 0
  while item_index < len(keys):
    item  = keys[item_index].lower()
    value = info[item]
    value = read(f' {keys[item_index]} [{value}]: ', value).strip()
    if value == '^':
      if item_index == 0:
        return None
      else:
        item_index -= 1
        continue
    info[item] = value
    item_index += 1

  info.update(
    {
      'album_name_orig' : album.get('album_name_orig', ''),
      'album_artists'   : artists,
      'date'            : album.get('date', '1970-01-01')
    }
  )

  save_song(f, info)

  name_lat = re.sub(r'\.+\s*$', '', info['title latin']).strip()
  new_name = os.path.join(discpath, f'{info["index"]:02} - {name_lat}.{ext}')
  os.rename(filename, new_name)

  return new_name

def process_album(dirname):
  print(os.path.realpath(dirname))

  files = natsorted(os.listdir(dirname))
  items = sort_music_items(dirname, files)

  album = get_album_info(dirname, items)

  if album.get('notes', ''):
    print('\n\nNotes:')
    print(album.get('notes', ''))

  album = user_modify_album(album)

  num_discs  = len(items)
  save_image(album['cover'], dirname)
  if album['thumb']:
    cover_data = requests.get(album['thumb']).content
  else:
    cover_data = None

  items   = sorted(items.items(), key=lambda x: x[0][0])
  index_1 = 0

  while index_1 < num_discs:
    (disc_num, discpath), files = items[index_1]
    disc           = album.get('discs', [])
    disc           = disc[disc_num-1] if len(disc) >= disc_num else {}
    num_songs      = len(files)
    disc['tracks'] = disc.get('tracks', [{}]*num_songs)

    if disc.get('cover', '') and discpath != dirname:
      #print(discpath)
      save_image(disc.get('cover', ''), discpath)

    index_1 += 1

    index = 0
    while index < min(len(files), len(disc['tracks']), num_songs):
      info     = disc['tracks'][index]
      filename = files[index]
      index += 1
      info.update(
        {
          'index'     : index,
          'num_songs' : num_songs,
          'disc_num'  : disc_num,
          'num_discs' : num_discs
        }
      )
      new_name = process_song(filename, cover_data, album, info, discpath)
      if new_name:
        files[index-1] = new_name
      else:
        if index == 1 and index_1 > 1:
          index_1 -= 1
          disc = None
          break
        else:
          index -= 2
          if index < 0:
            index = 0
          continue

  new_dirname = os.path.join(
    os.path.abspath(os.path.join(dirname, os.pardir)),
    re.sub('[ _-]+$', '',
            re.sub('[ _-]+', '_', album['album_name_latin'].strip())
    )
  )
  new_dirname = re.sub(r'\.+[_\s]*$', '', new_dirname).strip()
  print(f'\nrenaming "{dirname}" -> "{new_dirname}"\n\n')
  os.rename(dirname, new_dirname)

  index_1 += 1

for dirname in sys.argv[1:]:
  if os.path.isdir(dirname):
    process_album(dirname)
  else:
    process_song(dirname)
