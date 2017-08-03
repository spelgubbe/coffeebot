_ = require 'lodash'

Ichimoku = require './ichimoku'
log = require './logging'


makeRequest = (protocol, hostStr, pathStr) ->
	new Promise((resolve) ->
		obj = ''

		url = api + pathStr
		https = require(protocol)

		callback = (response) ->
			str = ''
			response.on 'data', (chunk) ->
				str += chunk

			response.on 'end', ->
				obj = JSON.parse(str)
				resolve obj

		https.request(url, callback).end()
)

epochTime = ->
	Math.floor new Date().getTime() / 1000

getFinishedCandles = (candles, lagSeconds = 60) ->
	finishedCandles = []
	timeInSeconds = epochTime() - lagSeconds
	i = 0
	while i < candles.length
		candle = candles[i]
		if candle[0] <= timeInSeconds
			finishedCandles.push candle
		i++
	finishedCandles

getLatestFinishedCandle = (candles, lagseconds = 60) ->
	_.last getFinishedCandles(candles, lagseconds)

candleToObj = (candle) ->
	candleObj = 
		time: candle[0]
		open: candle[1]
		high: candle[2]
		low: candle[3]
		close: candle[4]
		volume: candle[5]
	candleObj

candlesToObj = (fCandles) ->
	# OHLC format open high low close (volume)
	candles = []
	i = 0
	while i < fCandles.length
		candle = fCandles[i]
		candleObj = 
			time: candle[0]
			open: candle[1]
			high: candle[2]
			low: candle[3]
			close: candle[4]
			volume: candle[5]

		candles.push candleObj
		i++
	candles

candlesToArrays = (fCandles) ->
	open = []
	high = []
	low = []
	close = []
	volume = []
	i = 0
	while i < fCandles.length
		candle = fCandles[i]
		open.push(candle.open)
		high.push(candle.high)
		low.push(candle.low)
		close.push(candle.close)
		volume.push(candle.volume)
		i++

	return [open, high, low, close, volume]

toLocalTime = (time) ->
	d = new Date() # new date to check our timezone
	#offset = d.getTimezoneOffset() * 60000 # offset in milliseconds

	timeFormat = if time.toString().length == 10 then 'seconds' else 'milliseconds' # if time is 10 long, it's in seconds (otherwise it's in milliseconds)
	
	time = if timeFormat == 'seconds' then time*1000 else time

	d.setTime(time)

	return d.toLocaleString()

handleData = (arr, context, data) ->
	i = 0

	finished = getFinishedCandles(arr, 30)
	#console.log 'Current time', (new Date()).toLocaleString()
	#console.log 'Candle time ' + context.pairString.toUpperCase() + ':', toLocalTime(candleToObj(getLatestFinishedCandle(arr, 30)).time)
	fCandleObjArr = candlesToObj(finished)

	k = 0
	while k < fCandleObjArr.length
		data.instruments[context.instrument].open[k] = fCandleObjArr[k].open
		data.instruments[context.instrument].high[k] = fCandleObjArr[k].high
		data.instruments[context.instrument].low[k] = fCandleObjArr[k].low
		data.instruments[context.instrument].close[k] = fCandleObjArr[k].close
		data.instruments[context.instrument].volume[k] = fCandleObjArr[k].volume
		k++

	instrument = data.instruments[context.instrument]

	Ichimoku.handle(context, data)


runBot = (protocol, api, periodTime, path, context, data) ->
	makeRequest(protocol, api, path).then (array) ->

		lastPosition = if context.pos != null then context.pos.substr() else null
		
		handleData(array['result'][periodTime.toString()], context, data)
		#console.log '"gas" left for this hour = ' + Math.floor(Math.floor(array['allowance']['remaining'] / 1000000) / 40) + '%'
		if lastPosition != context.pos and lastPosition != null
			if context.pos == 'short'
				log.mad(context.exchange, context.instrument, 'position changed - short')
			else
				log.happy(context.exchange, context.instrument, 'position changed - long')
		else
			if context.pos == 'short'
				log.mad(context.exchange, context.instrument, 'SHORT')
			else if context.pos == 'long'
				log.happy(context.exchange, context.instrument, 'LONG')



arrlen = 500

data = 
	instruments:
		# this needs to be automated ......

		# BTC PAIRS
		'btc_usd':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)
		'btc_eur':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)
		
		# ETH PAIRS
		'eth_usd':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)
		'eth_eur':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)
		'eth_btc':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)

		# LTC PAIRS
		'ltc_usd':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)
		'ltc_eur':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)
		'ltc_btc':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)


protocol = 'https'
api = 'https://api.cryptowat.ch'

instrumentsToTrade = ['btc_usd','eth_usd', 'ltc_usd', 'eth_btc', 'ltc_btc']
exchanges = ['poloniex', 'poloniex', 'poloniex', 'poloniex', 'poloniex']

periodTime = 3600
lagSeconds = 30
firstRunTimeFilter = epochTime() - 3600 * (arrlen-1)

j = 0
contexts = []
# initialize all context variables
while j < instrumentsToTrade.length
	# mby göra om till class
	contexts[j] = {}
	context = contexts[j]
	context.instrument = instrumentsToTrade[j]
	context.exchange = exchanges[j]

	context.pair = instrumentsToTrade[j].split('_')

	context.asset = context.pair[0]
	context.currency = context.pair[1]
	context.pairString = context.pair.join('')

	context.path = '/markets/' + context.exchange + '/' + context.pairString + '/ohlc?periods=' + periodTime + '&after=' + firstRunTimeFilter

	Ichimoku.init(context)
	runBot(protocol, api, periodTime, context.path, context, data)

	j++

hasRun = false
millisecondsToWait = 3000;
setInterval((->

	now = new Date()
	timefilter = epochTime() - 3600 * (arrlen-1)
	
	if (now.getMinutes() == 0 && now.getSeconds() >= lagSeconds && hasRun == false)
		hasRun = true;
		k = 0
		while k < instrumentsToTrade.length
			context = contexts[k]
			context.path = '/markets/' + context.exchange + '/' + context.pairString + '/ohlc?periods=' + periodTime + '&after=' + timefilter
			runBot(protocol, api, periodTime, context.path, context, data)
			#console.log('Ran bot with:',context.instrument)
			k++
	else if (hasRun && now.getMinutes() > 0)
		
		hasRun = false
		)
, millisecondsToWait)