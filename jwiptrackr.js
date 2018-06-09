#!/usr/bin/env node
'use strict';

// usage: node jwiptracker.js CSPB-501234 ...
// or chmod u+x jwiptravcker.js and call: ./jwiptracker.js CSPB-501234 ...

// create a local file containing a single user:password line
// and secure it with chmod 600 credentials
const credentials_file = './credentials';

// update list of holidays
const holidays = [
	'2017-07-01',
	'2017-09-04',
	'2017-10-09',
	'2017-12-25',
	'2018-01-01',
	'2018-03-30',
	'2018-05-18',
	'2018-06-25',
	'2018-07-02',
	'2018-09-03',
	'2018-10-08',
	'2018-12-25'
];

///////////////////////////////////////////////////////////////////////////

const fs = require('fs');
const { spawnSync } = require('child_process');
const credentials = fs.readFileSync(credentials_file, 'utf8').trim();
improveDate();

let tickets = process.argv.slice(2);
//console.log("args:", args);
if (tickets.length == 0) {
	console.error('MISSING Ticket number(s). Usage: node jwiptrackr.js CSPB-543210 ...');
	process.exit(1);
}

let csv = [[
	'#Ticket', 'Summary', 'Type', 'Status', 'In Progress?', 'Original Estimate (hours)',
	'Time Spent (hours)', '(days)', 'Stretch (hours)', '(days)', 'Stretch Dates (from first to last In Progress status)'
]];
tickets.forEach(function (ticket) {
	if (/^[0-9]+$/.test(ticket)) ticket = 'CSPB-' + ticket;
	console.log('ticket:', ticket);

	let data = getTicketData(ticket);
	let computed = compute(data);

	console.log(`summary: ${data.fields.summary} (${data.fields.issuetype.name})`);
	console.log('current status:', data.fields.status.name);
	console.log('history:');
	console.log(computed.history);
	// stretch time is the time spent between the first 'In Progress' status
	// of the ticket until its completion (or now if it is still in progress),
	// ignoring all the intermediate status changes.
	// So it's the time spent between the first In Progress to the last one.
	console.log('stretch time:', h2dh(computed.stretch, 1), computed.stretch_msg);
	console.log('estimated at:', s2dh(data.fields.timeoriginalestimate, 1));
	console.log('working time spent:', h2dh(computed.working_hours, 1));
	if (computed.wip) console.log(`${ticket} is still a work in progress`);
	console.log('_________________________');

	csv.push([
		ticket,
		data.fields.summary.replace(/,/g, ' ').replace(/  +/g, ' '),
		data.fields.issuetype.name,
		data.fields.status.name,
		computed.wip ? 'WIP' : '',
		s2h(data.fields.timeoriginalestimate),
		computed.working_hours,
		h2dh(computed.working_hours),
		computed.stretch,
		h2dh(computed.stretch),
		computed.stretch_msg,
	]);
});

console.log()
csv.forEach(function (row) {
	console.log(row.join(','));
});

// get ticket data from JIRA server or filesystem if ticket name ends with ".json"
function getTicketData(ticket) {
	let json = '';
	if (/\.json$/i.test(ticket)) {
		json = fs.readFileSync(ticket, 'utf8');
	} else {
		let httpget = spawnSync('curl', [
			'-u', credentials,
			'-X', 'GET',
			'-H', 'Content-Type:application/json',
			`https://jira.expedia.biz/rest/api/latest/issue/${ticket.toUpperCase()}?expand=changelog`
		]);
		json = httpget.stdout.toString();
		const errstr = httpget.stderr.toString();
//		console.log('stderr:', errstr);
	}
	const data = JSON.parse(json);
//	console.log('data:', data);
	if (data.errorMessages) {
		console.error('ERROR', data);
		process.exit(1);
	}
	if (!data) {
		console.error("ERROR/NOT FOUND");
		process.exit(1);
	}
	return data;
}

// parse ticket changelog data
function compute(raw) {
	let first_date, first_date_str,
	    last_date, last_date_str,
	    current_wip_start_date,
	    working_hours = 0,
	    history = [];
	for (let entry of raw.changelog.histories) {
//		console.log(entry);
		for (let item of entry.items) {
			if (item.field != 'status') continue;
			history.push(`${entry.created}: ${item.fromString} ➔ ${item.toString}  by ${entry.author.name}`);
			last_date_str = entry.created;
			last_date = new Date(entry.created);
			if (item.toString == 'In Progress') {
				current_wip_start_date = last_date;
				if (!first_date) {
					first_date_str = last_date_str;
					first_date = last_date;
			}	}
			if (item.fromString == 'In Progress') {
				if (current_wip_start_date) {
					let r = getWorkhoursBetween(current_wip_start_date, last_date);
					working_hours += r.hours;
					history.push(r.msg);
					current_wip_start_date = 0;
				}
				if (!first_date) {
					first_date_str = last_date_str;
					first_date = last_date;
			}	}
		} // next item
	} // next entry
	if (current_wip_start_date) {
		// ticket is still in progress, calculate with last_date being now
		last_date_str = 'now';
		last_date = new Date();
		let r = getWorkhoursBetween(current_wip_start_date, last_date);
		working_hours += r.hours;
		history.push(r.msg);
	}

	let data = {};
	data.wip = !!current_wip_start_date;
	let stretch = getWorkhoursBetween(first_date, last_date);
	data.stretch = stretch.hours;
	data.stretch_msg = `from ${first_date_str} to ${last_date_str}`;
	data.working_hours = working_hours;
	data.history = history;
	return data;
}

function getWorkdaysBetween(d1, d2) {
	let days_between = [],
		current_day = d1.clone(); 
	current_day.setHours(0,0,0,1); // start just after midnight
	while (current_day <= d2) {
//		console.log(`+ ${current_day} wd? ${current_day.isWorkday()}`);
		if (current_day.isWorkday()) days_between.push(current_day.clone());
		current_day.oneDayLater();
	}
//	console.log(days_between);
	return days_between;
}

function getWorkhoursBetween(d1, d2) {
	let start_hour = d1.getHours(),
		end_hour = d2.getHours(),
		workdays_between = getWorkdaysBetween(d1, d2),
		hours_between = 0;
//	console.log(`from ${d1} at ${start_hour}`);
//	console.log(`  to ${d2} at ${end_hour}`);
	for (let day of workdays_between) {
//		console.log('day', day);
		if (day.isSameDayAs(d1) && day.isSameDayAs(d2)) {
			hours_between += end_hour - start_hour;
//			console.log(`${hours_between} added d1d2 ${end_hour - start_hour}`);
			continue;
		}
		if (day.isSameDayAs(d1)) {
			if (start_hour < 17)
				hours_between += Math.min(17 - start_hour, 8);
//			console.log(`${hours_between} added d1 ${Math.min(8, 17 - start_hour)}`);
			continue;
		}
		if (day.isSameDayAs(d2)) {
			if (end_hour > 9)
				hours_between += Math.min(end_hour - 9, 8);
//			console.log(`${hours_between} added d2 ${Math.min(8, end_hour - 9)}`);
			continue;
		}
		hours_between += 8; // 8-hour workday
//		console.log(`${hours_between} added full day`);
	}
	return {
		hours: hours_between,
		msg: `+${hours_between} hours from ${d1} to ${d2}`
	};
}

function h2dh(hours, show_hours) {
	let days = Math.floor(hours / 8),
		remainderhours = hours - days * 8,
		dh = '';
	if (days) dh = `${days}d`;
	if (days && remainderhours) dh += ' ';
	if (remainderhours) dh += `${remainderhours}h`;
	if (days && show_hours) dh += ` (${hours} hours)`;
	return dh;
}

function s2h(seconds) {
	return Math.round(seconds / 60 / 60);
}

function s2dh(seconds, show_hours) {
	return h2dh(s2h(seconds), show_hours);
}

// improve Date
function improveDate() {
	Date.prototype.clone = function() {
		return new Date(this.valueOf());
	}
	Date.prototype.oneDayLater = function() {
		return this.setDate(this.getDate() + 1);
	}
	Date.prototype.isSameDayAs = function(date) {
		return this.getFullYear() === date.getFullYear()
			&& this.getMonth() === date.getMonth()
			&& this.getDate() === date.getDate();
	}
	Date.prototype.isWeekend = function() {
		return this.getDay() == 0 || this.getDay() == 6;
	}
	Date.prototype.isHoliday = (function () {
		const holydates = holidays.map(it => { return new Date(it+'T00:00:00.001-0700'); });
		return function() {
			for (let holiday of holydates) if (this.isSameDayAs(holiday)) return true;
			return false;
		}
	})();
	Date.prototype.isWorkday = function() {
		return !this.isWeekend() && !this.isHoliday();
	}
}

/*
{ ..
  "changelog": {
    "startAt": 0,
    "maxResults": 31,
    "total": 31,
    "histories": [ ..,
      {
        "id": "23488625",
        "author": {
          "self": "https://jira.expedia.biz/rest/api/2/user?username=alevesque",
          "name": "alevesque",
          "key": "alevesque",
          "emailAddress": "a-alevesque@expedia.com",
          "avatarUrls": {
            "48x48": "https://jira.expedia.biz/secure/useravatar?ownerId=alevesque&avatarId=50608",
             ..
          },
          "displayName": "Alex Levesque",
          "active": true,
          "timeZone": "America/Los_Angeles"
        },
        "created": "2018-06-01T07:37:15.667-0700",
        "items": [
          {
            "field": "status",
            "fieldtype": "jira",
            "from": "10137",
            "fromString": "In Analysis",
            "to": "3",
            "toString": "In Progress"
          }
        ]
      }
    ]
  }
}
*/
