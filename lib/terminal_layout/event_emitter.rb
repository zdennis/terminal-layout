module TerminalLayout
  module EventEmitter
    def _callbacks
      @_callbacks ||= Hash.new { |h, k| h[k] = [] }
    end

    def on(type, *args, &blk)
      _callbacks[type] << blk
      self
    end

    def unsubscribe
      _callbacks.clear
    end

    def emit(type, *args)
      _callbacks[type].each do |blk|
        blk.call(*args)
      end
    end
  end
end
