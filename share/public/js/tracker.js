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

$(document).ready(function() {
  $('body').on('submit', 'form.api-form', function(e) {
    e.preventDefault();
    tracker.form_api_request($(this));
  });
  $('#upload-complete').on('submit', function(e) {
    e.preventDefault();
    tracker.form_api_request($(this), function(res) {
      window.location = "/tracker/upload/" + res.upload;
    });
  });

  $('#server-refresh').on('click', function(e) {
    e.preventDefault();
    $.ajax({
      type: 'GET',
      dataType: "json",
      url: '/tracker/api/my/upload/servers',
      data: { tags: $('#tags').val().split(",") },
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

  $('#server').on('change', function(e) {
    var select = $(this);
    var option = select.find("option:selected");
    var form = select.parents('form');
    form.attr('action', select.val());
    form.find('#token').val(option.attr('data-token'));
    form.find('#return').val(window.location.toString());
  });

  $('#new-upload').on('submit', function(e) {
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

  $('.server-status').each(function(i, el) {
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

  $('.timestamp').each(function() {
    var span = $(this);
    var date = new Date(span.text() * 1000);
    var year = date.getYear() + 1900;
    var display = [year, date.getMonth(), date.getDate()].join("/")
      + " " + [date.getHours(), date.getMinutes()].join(":");
    span.html(display);
  });

  $('.file-downloads').each(function() {
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
});  

