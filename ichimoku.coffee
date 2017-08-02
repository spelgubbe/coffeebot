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

module.exports = Ichimoku