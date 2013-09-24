# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$ ->
  window.gif = {
    width: 0,
    height: 0,
    frames: [],
    loaded: 0,
    current: 0,
    reconstructed: [],
    frameCount: 0,
    animating: false,
    lastWidth: 0,
    lastHeight: 0

    selectFrame: (fid=@current,resize=false)->
      fid = 0 if fid < 0
      fid = fid % @frameCount if fid >= @frameCount
      change = @current != fid || @context.canvas.width != @lastWidth || @context.canvas.height != @lastHeight
      return unless change
      @current = fid
      @lastWidth = @context.canvas.width
      @lastHeight = @context.canvas.height
      $('.frame.selected').removeClass('selected')
      frame = $("[href='##{fid}']")
      frame.addClass('selected')
      fw = frame.outerWidth(true)
      pos = fw * gif.current
      scroller = $('#frame-selector')
      mid = (scroller.innerWidth() - fw) / 2
      scroller.scrollLeft(Math.max(0, pos - mid))
      window.location.hash = frame.attr('href');
      @context.drawImage(@reconstructed[fid], 0, 0, @context.canvas.width, @context.canvas.height)
      $('#panel button').removeAttr('disabled')
      $('#next').attr('disabled', 'disabled') if fid == gif.frameCount - 1
      $('#prev').attr('disabled', 'disabled') if fid == 0

    next: -> @selectFrame(@current + 1)
    previous: -> @selectFrame(@current - 1)

    animate: =>
      return unless gif.animating
      gif.next()
      gif.animateId = setTimeout(gif.animate, gif.frames[gif.current].delay)

    animateToggle: ->
      @animating = !@animating
      if @animating
        @animateId = setTimeout(@animate, gif.frames[@current].delay)
      else
        clearTimeout(@animateId)
      but = $('#toggle')
      but.attr('title', 'Pause') if @animating
      but.attr('title', 'Play') unless @animating
      but.children('i').removeClass('icon-play').removeClass('icon-pause').addClass("icon-#{but.attr('title').toLowerCase()}")
  }

  window.getMetadata = ->
    updateEllipsis()
    path = '/metadata' + window.location.pathname;
    $.ajax({url: path, dataType: 'json'}).fail((jqXHR, textStatus, errorThrown) ->
      console?.log?(errorThrown)
      showError(textStatus)
    ).done((data, textStatus, jqXHR) ->
      unless data.status == 'ok'
        showError(data.message)
        return

      gif.dataPath = '/' + data.path + '/'

      $.ajax({url: gif.dataPath + 'metadata.json', dataType: 'json'}).fail((jqXHR, textStatus, errorThrown) ->
        console?.log?(errorThrown)
        showError(textStatus)
      ).done((data, textStatus, jqXHR) ->
        $('body').transition({'background-color': data.background})

        for frame in data.frames
          frame.delay ||= data.delay
          frame.x ||= 0
          frame.y ||= 0

        gif.width = data.width
        gif.height = data.height
        gif.current = Number((window.location.hash || '#0').substring(1)) || 0
        gif.frames = data.frames
        gif.frameCount = gif.frames.length

        sel = $('#frame-selector')
        for i in [0...gif.frameCount] by 1
          # Create selection box
          b = $('<a></a>')
          #b.attr('name', i)
          b.attr('href', "##{i}")
          b.addClass('frame')
          sel.append(b)

          # Load frames
          img = gif.frames[i].source = new Image()
          img.frame = i
          img.src = gif.dataPath + i + '.png'
          img.onload = ->
            gif.loaded++
            frame = $("[href='##{this.frame}']")
            frame.text(this.frame+1)

            setLoadingText('Loading image ' + (gif.loaded + 1) + ' / ' + gif.frameCount)
            if gif.loaded == gif.frameCount
              setLoadingText('Done!')
              $('#loading-overlay').fadeOut()

              canvas = document.getElementById('preview-area')
              unless canvas.getContext?
                showError('Your browser does not support HTML canvas')
                return

              ctx = gif.context = canvas.getContext('2d')
              ctx.canvas.width = gif.width;
              ctx.canvas.height = gif.height;
              $(canvas).css({margin: "#{-gif.height/2}px 0 0 #{-gif.width/2}px"})

              for frame in gif.frames
                ctx.drawImage(frame.source, frame.x, frame.y)
                setLoadingText('Reconstructing frame ' + (gif.reconstructed.length + 1) + ' / ' + gif.frameCount)
                rec = new Image()
                rec.src = canvas.toDataURL('image/png')
                target = $("[href='##{gif.reconstructed.length}']")
                target.css({'background-image': 'url(' + rec.src + ')'})
                gif.reconstructed.push(rec)

              $(window).resize()
              gif.selectFrame()
              $('#controls').mouseleave()
              gif.animateToggle()
        null
      )
    )

  window.setLoadingText = (text) ->
    updateEllipsis(0)
    $('#loading-text').text(text)

  window.updateEllipsis = (count = ((window.ellipsisCount || 0)+1)%3) ->
    window.ellipsisCount = count
    str = Array(count + 2).join('.')
    $('#loading-ellipsis').html(str)
    setTimeout(window.updateEllipsis, 500)

  window.showError = (message) ->
    alert(message)

  $(window).on('hashchange', (evt) ->
    gif.selectFrame(Number((window.location.hash || '#0').substring(1)))
  )

  $(document).on('focus', 'a.frame', (evt) ->
    e = $(evt.target)
    gif.selectFrame(Number(e.attr('href').substring(1)))
  )

  # Hide and show
  $('#controls').hover(
    (evt) ->
      $('#frame-selector').transition({ bottom: $('#panel').outerHeight(), queue: false })
    ,
    (evt) ->
      $('#frame-selector').transition({ bottom: -$('#frame-selector').outerHeight(), queue: false })
  )

  $(window).resize((evt) ->
    width = $(document.body).outerWidth()
    height = $(document.body).outerHeight()
    iw = gif.width
    ih = gif.height
    tw = iw
    th = ih
    ratio = iw/ih # height * ratio = w

    if height * ratio <= width
      th = height
      tw = height * ratio
    else
      th = width / ratio
      tw = width

    cw = gif.context.canvas.width = tw;
    ch = gif.context.canvas.height = th;
    gif.selectFrame(gif.current, true)
    $('#preview-area').css({margin: "#{-ch/2}px 0 0 #{-cw/2}px"})
  )