// fix bootstrap-table icons
window.icons = {
  refresh: 'fa-sync',
  toggle: 'fa-id-card',
  columns: 'fa-columns',
  clear: 'fa-trash'
};

function timeSince(date) {
  var seconds = Math.floor((new Date() - date) / 1000);
  var interval = Math.floor(seconds / 31536000);
  if (interval > 1) {
    return interval + " years ago";
  }
  interval = Math.floor(seconds / 2592000);
  if (interval > 1) {
    return interval + " months ago";
  }
  interval = Math.floor(seconds / 86400);
  if (interval > 1) {
    return interval + " days ago";
  }
  interval = Math.floor(seconds / 3600);
  if (interval > 1) {
     return interval + " hours ago";
  }
  interval = Math.floor(seconds / 60);
  if (interval > 1) {
    return interval + " minutes ago";
  }
  return Math.floor(seconds) + " seconds ago";
}

function formatHashRateValue(value) {
  var sizes = ['H/s','KH/s','MH/s','GH/s','TH/s'];
  if (value == 0) return '0 H/s';
  if (isNaN(value)) return '-';
  var i = Math.floor(Math.log(value) / Math.log(1000));
  return parseFloat((value / Math.pow(1000, i)).toFixed(2)) + ' ' + sizes[i];
};

function formatHashRate(value) {
  if (Array.isArray(value)) {
    return value.map(formatHashRate).toString();
  } else {
    return formatHashRateValue(value);
  }
}
  
function formatBTC(value) {
  return parseFloat(value).toFixed(8);
};

function formatArrayAsString(value) {
  return value.toString();
};

function formatMinerHashRatesAlgorithms(value) {
  return Object.keys(value).toString();
};

function formatMinerHashRatesValues(value) {
  hashrates = [];
  for (var property in value) {
    hashrates.push(formatHashRateValue(value[property]));
  }
  return hashrates.toString();
}

function detailFormatter(index, row) {
  var html = [];
  $.each(row, function (key, value) {
    html.push('<p class="mb-0"><b>' + key + ':</b> ' + JSON.stringify(value) + '</p>');
  });
  return html.join('');
}

function formatBytes(bytes) {
  decimals = 2
  if(bytes == 0) return '0 Bytes';
  var k = 1024,
    dm = decimals || 2,
    sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'],
    i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}
  