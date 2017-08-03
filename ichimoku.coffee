_ = require 'lodash'

class Ichimoku
	constructor: (@tenkan_n = 9,@kijun_n = 26)->
		@tenkan = Array(@kijun_n) 					# array length is 26 (shouldn't it be 9?)
		#@tenkan = Array(@tenkan_n)
		@kijun = Array(@kijun_n) 					# array length is 26
		@senkou_a = Array(@kijun_n * 2)				# array length is 52
		@senkou_b = Array(@kijun_n * 2)				# array length is 52
		@chikou = []								#  lag-line "chikou span"

		# ins = instrument = the asset you're trading
		# ins.low is the lowest price for the asset in a period

	put: (ins) ->
		@tenkan.push(this.calc(ins, @tenkan_n)) # tenkan = (hh + ll)/2 (lowest and highest in 9 periods)
		@kijun.push(this.calc(ins, @kijun_n)) # kijun = lowest and highest / 2 in 26 periods
		
		# senkou a = c.tenkan + c.kijun / 2 (is showed 26 periods ahead)
		@senkou_a.push((@tenkan[@tenkan.length-1] + @kijun[@kijun.length-1])/2)

		# lowest low + highest high / 2 over 52 periods - plotted 26 periods ahead
		@senkou_b.push(this.calc(ins, @kijun_n * 2))

		# closing price of the period, plotted 26 periods after the current one
		@chikou.push(ins.close[ins.close.length - 1])
	current: ->
		c = 
			tenkan: @tenkan[@tenkan.length-1] 				# current tenkan
			kijun: @kijun[@kijun.length-1]					# current kijun
			senkou_a: @senkou_a[@senkou_a.length-1-@kijun_n]	# senkou_a 26 indexes back
			senkou_b: @senkou_b[@senkou_b.length-1-@kijun_n]	# senkou_b 26 indexes back
			chikou: @chikou[@chikou.length-1]
			lag_senkou_a: @senkou_a[@senkou_a.length-1-(@kijun_n*2)] # furthest back senkou_a
			lag_senkou_b: @senkou_b[@senkou_b.length-1-(@kijun_n*2)] # furthest back senkou_b
		
		return c

		# calculate low and high of an amount of periods (n)
	calc: (ins,n) ->
		hh = _.max(ins.high[-n..])
		ll = _.min(ins.low[-n..])
		return (hh + ll) / 2

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
	#if context.pos == 'long'
		#cash = @portfolio.positions[instrument.base()].amount
		#if cash > 15
			#trading.buy(instrument, 'market', Math.round(1000*cash/instrument.price - 1)/1000)
		#happy_log(context.exchange, context.instrument, 'LONG')
	#else if context.pos == 'short'
		#asset = @portfolio.positions[instrument.asset()].amount
		#if asset > 0.2
			#trading.sell(instrument, 'market', asset)
		#mad_log(context.exchange, context.instrument, 'SHORT')

exports.init = init
exports.handle = handle
#exports.Ichimoku = Ichimoku