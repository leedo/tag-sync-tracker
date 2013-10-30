var tracker = {};

tracker.update_partial = function(id) {
  $.ajax({
    type: "GET",
    url: window.location.toString(),
    dataType: "html",
    success: function(html) {
      var container = $('<div/>').html(html).hide();
      var replacement = container.find('#' + id).remove();
      $('#' + id).replaceWith(replacement);
      container.remove();
      tracker.setup_events($('#' + id));
    }
  });
};

tracker.form_data = function(form) {
  var data = {};
  $.each(form.serializeArray(), function(i, input) {
    if (input['name'] == "_method")
      method = input['value']
    else
      data[input['name']] = input['value'];
  });
  return data;
};

tracker.form_api_request = function(form, success) {
  if (form.hasClass("confirm") && !confirm("Are you sure?"))
    return;

  $.ajax({
    url: form.attr('action'),
    type: form.attr('method'),
    data: tracker.form_data(form),
    dataType: "json",
    success: function(res) {
      if (res.error) {
        var status = form.find('.status');
        if (status.length)
          status.addClass('error').html(res.error);
        else
          alert(res.error);
      }
      else if (success) {
        success(res);
      }
      else {
        var partial = form.attr('data-partial')
        if (partial)
          tracker.update_partial(partial);
      }
    }
  });
};

tracker.setup_events = function(root) {
  root.find('form.api-form').on('submit', function(e) {
    e.preventDefault();
    tracker.form_api_request($(this));
  });

  root.find('#upload-complete').on('submit', function(e) {
    e.preventDefault();
    tracker.form_api_request($(this), function(res) {
      window.location = "/tracker/upload/" + res.upload;
    });
  });

  root.find('#new-upload #tag-input, form.tag-input input[type="text"]').typeahead({
    name: "tags",
    prefetch: "/tracker/tags.json",
    limit: 10
  });

  root.find('#new-upload #tag-input').on('keypress', function(e) {
    if (e.keyCode != 13)
      return;

    e.preventDefault();
    var input = $(this);
    var tag = input.val();
    var list = $('#tag-list');
    var hidden = $('<input/>', {
      type: "hidden",
      value: tag,
      name: "tags"
    });
    list.append($('<li/>').html(tag).append(hidden));
    input.typeahead('setQuery', '');
  });

  root.find('form.user-input input[type="text"]').typeahead({
    name: "users",
    remote: "/tracker/users.json?q=%QUERY",
    limit: 10
  });

  root.find('.tag-input input, .user-input input').on('keypress', function(e) {
    if (e.keyCode == 13) {
      $(this).parents("form").submit();
    }
  });

  root.find('.mirror-everything input[type="checkbox"]').on("change", function(e) {
    var orig = $(this);
    var input = $('<input/>',{name: "everything", type: "hidden"});
    input.val(orig.prop("checked") ? "on" : "off");
    orig.replaceWith(input);
    input.parents("form").submit();
  });

  root.find('#server-refresh').on('click', function(e) {
    e.preventDefault();
    var tags = $.map($('input[name="tags"]'), function(input) {
      return $(input).val();
    });
    $.ajax({
      type: 'GET',
      dataType: "json",
      url: '/tracker/api/my/upload/servers',
      data: { tags: tags },
      success: function(res) {
        if (res['error']) {
          console.log(res['error']);
          return;
        }
        var select = $("#server").removeAttr('disabled').html("");
        if (res.servers.length == 0) {
          select.append($('<option/>' ).html("No matching servers, try adding some tags."));
          select.attr('disabled', 'disabled');
          return;
        }
        $(res.servers).each(function(i, server) {
          var opt = $('<option/>', {
            "value": server.url,
            "data-token": server.token
          }).html(server.name);
          select.append(opt);
        });
        select.trigger("change");
      }
    });
  });

  root.find('#server').on('change', function(e) {
    var select = $(this);
    var option = select.find("option:selected");
    var form = select.parents('form');
    form.attr('action', select.val());
    form.find('#token').val(option.attr('data-token'));
    form.find('#return').val(window.location.toString());
  });

  root.find('#new-upload').on('submit', function(e) {
    if (!"getFormData" in this) return;
    e.preventDefault();

    var form = $(this);

    form.append($('<input/>', {
      name: "is_js",
      value: true,
      type: "hidden"
    }));

    var data = new FormData(this)
      , xhr = new XMLHttpRequest()
      , prog = form.find('.progress-container')
      , bar = form.find('.progress-bar')
      , submit = form.find('#upload-submit')
      , abort = form.find('.progress-abort')
      , status = form.find('.status');

    status.removeClass('error').html('');
    submit.hide();
    prog.show();

    form.find('input,button,select').attr('disabled','disabled');
    abort.removeAttr('disabled');

    abort.on('click', function(e) {
      e.preventDefault();
      xhr.abort();
      prog.hide();
      submit.show();
      form.find('input,button,select').removeAttr('disabled');
    });

    xhr.upload.addEventListener("progress", function(e) {
      var progress = parseInt((e.loaded / e.total) * 100);
      bar.css({width: progress + "%"});
    }, false);

    xhr.addEventListener("load", function(e) {
      var res = JSON.parse(this.responseText);
      if (res.location) {
        window.location = res.location;
      }
      else {
        var error = res.error || "unknown error";
        status.addClass('error').html(error);
        prog.hide();
        submit.show();
        form.find('input,button,select').removeAttr('disabled');
      }
    }, false);

    xhr.open("POST", $(this).attr("action"), true);
    xhr.send(data);
  });

  root.find('.server-status').each(function(i, el) {
    var el = $(el);
    $.ajax({
      type: "get",
      url: el.attr('data-status-url'),
      dataType: "json", // could use jsonp, but CORS headers allow this
      success: function(res) {
        el.addClass("up");
      },
      error: function(res) {
        el.addClass("down");
      }
    });
  });

  root.find('.timestamp').each(function() {
    var span = $(this)
      , date = new Date(span.text() * 1000)
      , year = date.getYear() + 1900
      , mon  = date.getMonth()
      , day  = date.getDate()
      , min  = date.getMinutes()
      , hour = date.getHours();

    if (min < 10) min = "0" + String(min);
    if (hour < 10) hour = "0" + String(hour);
    if (mon < 10) mon = "0" + String(mon);
    if (day < 10) mon = "0" + String(day);

    span.html([year, mon, day].join("/") + " " + [hour, min].join(":"));
  });

  root.find('.file-downloads').each(function() {
    var container = $(this)
      , hash = container.attr('data-hash')
      , id = container.attr('data-id');

    $.ajax({
      type: "GET",
      url: "/tracker/api/upload/" + id + "/servers",
      dataType: "json",
      success: function(res) {
        $(res.servers).each(function(i, server) {
          var url = server.url + "/download/" + hash + "?token=" + server.token;
          var link = $('<a/>',{href: url}).html(server.name);
          container.append($('<li/>').append(link));
          $.ajax({
            type: "GET",
            url: server.url + "/download/" + hash,
            data: {token: server.token, exists: true},
            dataType: "json",
            success: function(res) {
              link.addClass(res.success ? "up" : "down");
            }
          });
        });
      }
    });
  });
}

$(document).ready(function() {
  tracker.setup_events($(document));
});

