import tldextract
import sys
import os
from cerberus import Validator


def create_domain_key_2_host_map(hosts):
	key2hosts = {}
	for host in hosts:
		# don't merge blog sites
		if host.find(".blogspot.") >= 0 or host.find(".wordpress.") >= 0:
			key = host
		else:
			key = tldextract.extract(host).domain

		if key not in key2hosts:
			key2hosts[key] = []
		key2hosts[key].append(host)
	return key2hosts


def parent_folder_2_warcs(warcs):
	f2w = {}
	for warc in warcs:
		folder = warc.split('/')[-2]
		if folder not in f2w:
			f2w[folder] = []
		f2w[folder].append(warc)
	return f2w


def get_lang_or_default(scripts_dict, language):
	cmd = ""
	if language in scripts_dict:
		cmd = scripts_dict[language]
	elif "default" in scripts_dict:
		cmd = scripts_dict["default"]
	return cmd


def get_customnbp(nbp_dict, language):
	nbp = ""
	if language in nbp_dict:
		nbp = nbp_dict[language]
	
	return nbp


def validate_args(config):
	schema = {
			# required parameters
			'bitextor': {'required': True, 'type': 'string'},
			# output folders
			'dataDir': {'type': 'string', 'required': True},
			'permanentDir': {'type': 'string', 'required': True},
			'transientDir': {'type': 'string', 'required': True},
			'tempDir': {'type': 'string'},
			# execute until X:
			'onlyCrawling': {'type': 'boolean'},
			'onlyPreprocess': {'type', 'boolean'},
			# data definition
			# TODO: check that one of these is specified?
			'hosts': {'type': 'list'},
			'hostsFile': {'type': 'string', 'check_with': os.path.isfile},
			'warcs': {'type': 'list'},
			# crawling
			'crawler': {'required': True, 'type': 'string', 'allowed': ["wget", "heritrix", "creepy", "httrack"]},
			'crawlTimeLimit': {'type': 'string'},
			'crawlerUserAgent': {'type': 'string', 'dependencies': {'cralwer' : ['creepy', 'wget', 'httrack']}},
			'crawlWait': {'type': 'string', 'dependencies': {'crawler': ['creepy', 'wget', 'httrack']}},
			'crawlPageLimit': {'type': 'string', 'dependencies': {'crawler' : 'httrack'}},
			'crawlFileTypes': {'type': 'string', 'dependencies': {'crawler' : 'wget'}},
			'crawl-tld': {'type': 'boolean', 'dependencies': {'crawler' : 'creepy'}},
			'crawlSizeLimit': {'type': 'string', 'dependencies': {'crawler' : 'creepy'}},
			'crawlerNumThreads': {'type': 'string', 'dependencies': {'crawler' : 'creepy'}},
			'crawlerConnectionTimeout': {'type': 'string', 'dependencies': {'crawler' : 'creepy'}},
			'dumpCurrentCrawl': {'type': 'string', 'dependencies': {'crawler' : 'creepy'}},
			'resumePreviousCrawl': {'type': 'string', 'dependencies': {'crawler' : 'creepy'}},
			'heritrixPath': {'type': 'string', 'dependencies': {'crawler' : 'heritrix'}},
			'heritrixUrl': {'type': 'string', 'dependencies': {'crawler' : 'heritrix'}},
			'heritrixUser': {'type': 'string', 'dependencies': {'crawler' : 'heritrix'}},
			# preprocessing
			'langs': {'type': 'set'},
			'preprocessor': {'type': 'string', 'allowed': ['warc2preprocess', 'giawarc']},
			'giawarc_executable': {'type': 'string', 'dependencies': {'preprocessor': 'giawarc'}}, # TODO: check that is exists, and is executable
			'cleanHTML': {'type': 'boolean'},
			'ftfy': {'type': 'boolean'},
			'PDFextract': {'type': 'boolean'},
			'langID': {'type': 'string', 'allowed': ['cld2', 'cld3']},
			'parser': {'type': 'string', 'allowed': ['alcazar', 'bs4', 'modest', 'simple'], 'dependencies': {'preprocessor': ['warc2preprocess', '']}},
			'boilerpipeCleaning': {'type': 'boolean', 'dependencies': {'preprocessor': ['warc2preprocess', '']}},
			# tokenization
			'sentenceSplitters': {'type': 'dict'},
			'customNBPs': {'type': 'dict'},
			'workTokenizers': {'type': 'dict'},
			'norphologicalAnalysers': {'type': 'dict'},
			'pruneThreshold': {'type': 'integer'},
			'pruneType': {'type': 'string', 'allowed': ['words', 'chars']},
			# document alignment
			'lang1': {'type': 'string'},
			'lang2': {'type': 'string'},
			'documentAligner': {'type': 'string', 'allowed': ['DIC', 'externalMT']},
			'alignerCmd': {'type': 'string', 'dependencies': {'documentAligner': 'externalMT'}},
			'documentAlignerThreshold': {'type': 'float', 'dependencies': {'documentAligner': 'externalMT'}},
			'dic': {'type': 'string', 'check_with': os.path.isfile}, # TODO: depends on documentAligner=DIC, or sentenceAligner=hunalign
			}

	if 'crawler' in config and config['crawler'] == 'heritrix':
		schema['heritrixPath']['required'] = True
	if 'documentAligner' in config and config['documentAligner'] == 'DIC':
		schema['dic']['required'] = True
	if ('onlyPreprocess' not in config or not config['onlyPreprocess']) and ('onlyCrawl' not in config or not config['onlyCrawl']):
		schema['lang1']['required'] = True
		schema['lang2']['required'] = True
		# TODO: also check that sentence splitters / word tokenizers / morph analysers are provided for lang1 and lang2

	elif ('onlyPreprocess' in config and config['onlyPreprocess']) and ('lang1' not in confing or 'lang2' not in config):
		# if onlyPreprocess in true, target languages should be indicated either with 'lang1' and 'lang2', or 'langs'
		schema['langs']['required'] = True

	v = Validator(schema)
	b = v.validate(config)

	if not b:
		print("Validation error. Stopping.", v.errors, file=sys.stderr)
		exit()
