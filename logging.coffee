ch = require 'chalk'

exports.neutral = ->
	if console
		Array::unshift.call(arguments, (new Date()).toLocaleString() + ':')
		console.log.apply(console, arguments)

exports.happy = ->
	if console
		for key,val of arguments
			arguments[key] = ch.green(val.toUpperCase())
		Array::unshift.call(arguments, (new Date()).toLocaleString() + ':')
		console.log.apply(console, arguments)

exports.mad = ->
	if console
		for key,val of arguments
			arguments[key] = ch.red(val.toUpperCase())
		Array::unshift.call(arguments, (new Date()).toLocaleString() + ':')
		console.log.apply(console, arguments)