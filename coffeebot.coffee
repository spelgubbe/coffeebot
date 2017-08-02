_ = require 'lodash'
ch = require 'chalk'

Ichimoku = require('./ichimoku')

init = (context)->
	context.ichi = new Ichimoku()
	context.init = true
	context.pos = null

	###
	UPTREND SETTINGS:
		context.open = 7.0
		context.close = 3.5

		context.open = 4.0
		context.close = 5.0
								två nedersta bäst
		context.open = 4.0
		context.close = 6.0

	DOWNTREND SETTINGS:
		context.open = 0.2
		context.close = 0.5
	###
	context.open = 0.2
	context.close = 0.5
handle = (context, data)->
	# data object provides access to the current candle (ex. data['btc_usd'].close)
	#instrument = @data.instruments['btc_usd'] # tydligen fanns data i en klass (this.data), men inte i denna bot atm
	instrument = data.instruments[context.instrument]
	# TYDLIGEN
	# så fungerar det så här
	# instrument fylls med hundratals värden (vid uppstart av skriptet är length=498)
	# i detta skript behövs dock bara kijun_n antal aka 26 i detta fall
	# bara hämta mer från cryptowatch
	# handle körs varje 1h (eller perioden man angett)

	# init körs endast en gång under skriptets livstid
	if context.init # detta if-sats körs endast 1 gång
		for i in [0...instrument.close.length]
			t =
				open: instrument.open[..i]
				close: instrument.close[..i]
				high: instrument.high[..i]
				low: instrument.low[..i]
			context.ichi.put(t)
		context.init = false
	context.ichi.put(instrument)
	c = context.ichi.current()


	# short term (hh+ll)/2 -  long term......
	diff = 100 * ((c.tenkan - c.kijun) / ((c.tenkan + c.kijun)/2))
	diff = Math.abs(diff)

	# lägsta värdet för (hh+ll)/2 under de senaste 26 perioderna (lägsta mellan)
	min_tenkan = _.min([c.tenkan, c.kijun])
	# största värdet för (hh+ll)/2 under de senaste 26 perioderna (lägsta mellan)
	max_tenkan = _.max([c.tenkan, c.kijun])

	min_senkou = _.min([c.senkou_a, c.senkou_b])
	max_senkou = _.max([c.senkou_a, c.senkou_b])

	min_lag = _.min([c.lag_senkou_a, c.lag_senkou_b])
	max_lag = _.max([c.lag_senkou_a, c.lag_senkou_b])

	# Tenkan = short term price
	# Kijun = long(er) term price
	if diff >= context.open 						# determine if it's a profitable enough buy
		# short term > long term && 
		if c.tenkan > c.kijun and min_tenkan > max_senkou and c.chikou > max_lag
			context.pos = 'long'
		else if c.tenkan < c.kijun and max_tenkan < min_senkou and c.chikou < min_lag
			context.pos = 'short'
	
	if diff >= context.close 						# profitable enough sell
		if context.pos == 'short' and c.tenkan > c.kijun # short term > long term
			context.pos = 'long'
		else if context.pos == 'long' and c.tenkan < c.kijun # short term < long term
			context.pos = 'short'
	if context.pos == 'long'
		#cash = @portfolio.positions[instrument.base()].amount
		#if cash > 15
			#trading.buy(instrument, 'market', Math.round(1000*cash/instrument.price - 1)/1000)
		positivePrint(context.exchange + ' ' +context.instrument.toUpperCase()+':BUY')
	else if context.pos == 'short'
		#asset = @portfolio.positions[instrument.asset()].amount
		#if asset > 0.2
			#trading.sell(instrument, 'market', asset)
		negativePrint(context.exchange + ' ' +context.instrument.toUpperCase()+':SELL')


# END ICHI CLASS + FUNCTIONS

functionPrint = (string) ->
	console.log((new Date()).toLocaleString() + ': ' + string)

positivePrint = (string) ->
	functionPrint(ch.green(string))

negativePrint = (string) ->
	functionPrint(ch.red(string))

makeRequest = (protocol, hostStr, pathStr) ->
	new Promise((resolve) ->
		obj = ''

		###let options = {
				host:hostStr,
				path:pathStr,
				//method:"POST",
				//headers:{"Cookie":"JSESSIONID="+token}
		};
		###

		url = api + pathStr
		https = require(protocol)

		callback = (response) ->
			str = ''
			response.on 'data', (chunk) ->
				str += chunk
				return
			response.on 'end', ->
				obj = JSON.parse(str)
				resolve obj
				return
			return

		https.request(url, callback).end()
		#request.write('{"id":"ID","method":"'+ method +'","params":{},"jsonrpc":"2.0"}');
		#request.end();
		return
)

timeToISO = (time) ->
	new Date(time).toISOString()

timeToUTC = (time) ->
	new Date(time).toUTCString()

epochToISO = (epochtime) ->
	new Date(epochtime * 1000).toISOString()

epochTimeMS = ->
	new Date().getTime()

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
	# OHLC format open high low close
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

handle_data = (arr, context, data) ->
	i = 0

	finished = getFinishedCandles(arr, 30)
	console.log 'Current time', (new Date()).toLocaleString()
	#console.log 'Finished candles:', finished.length
	#console.log 'Latest candle', context.instrument.toUpperCase()
	console.log 'Candle time ' + context.pairString.toUpperCase() + ':', toLocalTime(candleToObj(getLatestFinishedCandle(arr, 30)).time)
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
	#console.log('körs detta?') # ja
	#console.log instrument#.push(candlesToObj(finished))
	#console.log('test', instrument.close[-26..]) # ichi test...
	#console.log data.btc_usd
	handle(context, data)


runBot = (protocol, api, path, context, data) ->
	makeRequest(protocol, api, path).then (array) ->
		# here is what you want
		#console.log array['result']['3600']
		handle_data(array['result']['3600'], context, data)
		#console.log '"gas" left for this hour = ' + Math.floor(Math.floor(array['allowance']['remaining'] / 1000000) / 40) + '%'
		#console.log data.instruments[0]

protocol = 'https'
api = 'https://api.cryptowat.ch'

arrlen = 500

data = 
	instruments:
		'btc_usd':
			open: Array(arrlen)
			high: Array(arrlen)
			low: Array(arrlen)
			close: Array(arrlen)
			volume: Array(arrlen)

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
		'btc_eur':
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




instrumentsToTrade = ['eth_usd', 'eth_btc', 'btc_usd']
exchanges = ['poloniex', 'poloniex', 'poloniex']

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
	console.log(context.path)

	init(context)
	runBot(protocol, api, context.path, context, data)

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
			runBot(protocol, api, context.path, context, data)
			console.log('Ran bot with:',context.instrument)
			k++
	else if (hasRun && now.getMinutes() > 0)
		# change hasRun to
		hasRun = false
		)
, millisecondsToWait)