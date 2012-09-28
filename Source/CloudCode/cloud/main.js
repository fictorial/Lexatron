// Parse Cloud Code for Lexatron iOS app
// Brian Hammond <brian@fictorial.com>

var PENDING = 0;
var DECLINED = 1;
var ACTIVE = 2;
var ENDED_NORMAL = 3;
var ENDED_RESIGN = 4;
var ENDED_TIMEOUT = 5;
var ENDED_AUTO_DECLINED = 6;

var TURN_PLAY = 0;
var TURN_PASS = 1;
var TURN_EXCHANGE_TILES = 2;
var TURN_RESIGN = 3;
var TURN_DECLINE = 4;
var TURN_TIMEOUT = 5;
var TURN_BOMB = 6;

var MAX_MATCHES = 25;

Parse.Cloud.define("hello", function (request, response) {
  response.success("Hello!");
});

function getDisplayName(user) { 
  var dname = user.get("displayName");
  if (dname)
    return dname;
  return user.getUsername();
}

// http://ejohn.org/blog/javascript-pretty-date
function prettyDate(time) {
  var date = new Date((time || "").replace(/-/g,"/").replace(/[TZ]/g," ")),
      diff = (((new Date()).getTime() - date.getTime()) / 1000),
      day_diff = Math.floor(diff / 86400);

  if ( isNaN(day_diff) || day_diff < 0 || day_diff >= 31 )
    return;

  return day_diff == 0 && (
      diff < 60 && "just now" ||
      diff < 120 && "1 minute ago" ||
      diff < 3600 && Math.floor( diff / 60 ) + " minutes ago" ||
      diff < 7200 && "1 hour ago" ||
      diff < 86400 && Math.floor( diff / 3600 ) + " hours ago") ||
    day_diff == 1 && "Yesterday" ||
    day_diff < 7 && day_diff + " days ago" ||
    day_diff < 31 && Math.ceil( day_diff / 7 ) + " weeks ago";
}

function summarizeActivityForMatches(matches, user) {
  var synopses = [];

  //matches.sort(function (m1, m2) {
  //  if (m1.updateAt > m2.updateAt) return -1;
  //  if (m1.updateAt < m2.updateAt) return 1;
  //  return 0;
  //});

  for (var i in matches) {
    var match = matches[i];

    var firstPlayer = match.get("firstPlayer");
    var allTurns = match.get("turns");

    // Random matches in pending state have no first player; remove those.
    // Random matches in which a player has been found and set have no turns yet potentially.
    // Note that other matches will not have this setup.
    // Thus, exclude matches that have 0-length 'turns'.

    if (typeof firstPlayer == 'undefined' || typeof allTurns == 'undefined' || allTurns.length == 0)
      continue;

    var secondPlayer = match.get("secondPlayer");

    var currentPlayerNumber = match.get("currentPlayerNumber");
    var currentPlayer = currentPlayerNumber == 0 ? firstPlayer : secondPlayer;
    var opponentPlayer = currentPlayerNumber == 1 ? firstPlayer : secondPlayer;

    var winningPlayerNumber = match.get("winningPlayer");
    var losingPlayerNumber = match.get("losingPlayer");

    var scoreForFirstPlayer = match.get("scoreFirstPlayer");
    var scoreForSecondPlayer = match.get("scoreSecondPlayer");

    var currentUserPlayerNumber = -1;
    var opponentPlayerNumber = -1;

    var currentName = null;
    var opponentName = null;

    if (firstPlayer.id == user.id) {
      currentName = getDisplayName(firstPlayer);
      opponentName = getDisplayName(secondPlayer);

      currentUserPlayerNumber = 0;
      opponentPlayerNumber = 1;
    } else {
      opponentName = getDisplayName(firstPlayer);
      currentName = getDisplayName(secondPlayer);

      opponentPlayerNumber = 0;
      currentUserPlayerNumber = 1;
    }

    var matchDescription = null;

    var mostRecentTurn = allTurns[allTurns.length-1];

    if (mostRecentTurn.state == ENDED_NORMAL) {
      var winningScore = winningPlayerNumber == 0 ? scoreForFirstPlayer : scoreForSecondPlayer;
      var losingScore = losingPlayerNumber == 0 ? scoreForFirstPlayer : scoreForSecondPlayer;

      if (winningPlayerNumber == -1 && 
          losingPlayerNumber  == -1) {
        matchDescription = "You tied vs " + opponentName + " (" + scoreForFirstPlayer + " - " + scoreForSecondPlayer + ")";
      } else if (winningPlayerNumber == currentUserPlayerNumber) {
        matchDescription = "You won vs " + opponentName + " (" + winningScore + " - " + losingScore + ")";
      } else if (losingPlayerNumber == currentUserPlayerNumber) {
        matchDescription = opponentName + " won " + " (" + winningScore + " - " + losingScore + ")";
      }
    } else if (mostRecentTurn.turnType == TURN_PASS) {
      if (currentUserPlayerNumber == currentPlayerNumber) {
        matchDescription = opponentName + " passed";
      } else {
        matchDescription = "You passed vs " + opponentName;
      }
    } else if (mostRecentTurn.turnType == TURN_PLAY) {
      var words = mostRecentTurn.wordsFormed.join(", ");
      if (currentUserPlayerNumber == currentPlayerNumber) {
        matchDescription = opponentName + " played " + words + " for " + mostRecentTurn.scoreDelta + " points";
      } else {
        matchDescription = "You played " + words + " for " + mostRecentTurn.scoreDelta + " points vs " + opponentName;
      }
    } else if (mostRecentTurn.turnType == TURN_RESIGN) {
      if (currentUserPlayerNumber == currentPlayerNumber) {
        matchDescription = "You resigned vs " + opponentName;
      } else {
        matchDescription = opponentName + " resigned";
      }
    } else if (mostRecentTurn.turnType == TURN_TIMEOUT) {
      if (currentUserPlayerNumber == currentPlayerNumber) {
        matchDescription = "You forfeited vs " + opponentName;
      } else {
        matchDescription = opponentName + " forfeited";
      }
    } else if (mostRecentTurn.turnType == TURN_EXCHANGE_TILES) {
      if (currentUserPlayerNumber == currentPlayerNumber) {
        matchDescription = opponentName + " exchanged tiles";
      } else {
        matchDescription = "You exchanged tiles vs " + opponentName;
      }
    } else if (mostRecentTurn.turnType == TURN_BOMB) {
      var bombCount = mostRecentTurn.bombsDetonated.length;
      if (currentUserPlayerNumber == currentPlayerNumber) {
        matchDescription = opponentName + " detonated " + (bombCount == 1 ? "a bomb" : bombCount + " bombs!");
      } else {
        matchDescription = "You detonated " + (bombCount == 1 ? "a bomb" : bombCount + " bombs!");
      }
    }

    // Check if the match should be forfeited for lack of activity by the
    // opponent.  That is, it's the opponent's turn and they haven't played in a while.
    //
    // Note for pending matches, don't penalize the players. Just delete the match.
    //
    // Note: We can only reliably do this on the server.

    var dayDiff;
    if (currentPlayerNumber == opponentPlayerNumber) {
      var diff = ((new Date()).getTime() - (new Date(match.updatedAt)).getTime()) / 1000;
      dayDiff = Math.floor(diff / 86400);

      var matchState = match.get("state");

      if (dayDiff >= 10 && matchState == ACTIVE) {
        match.set("winningPlayer", currentUserPlayerNumber);
        match.set("losingPlayer", opponentPlayerNumber);
        match.set("state", ENDED_TIMEOUT);
        match.save();
        continue;
      } 
      
      if (dayDiff >= 3 && matchState == PENDING) {
        match.set("winningPlayer", -1);
        match.set("losingPlayer", -1);
        match.set("state", ENDED_AUTO_DECLINED);
        match.save();
        continue;
      }
    }

    synopses.push({
      matchID: match.id,
      desc: matchDescription,
      updated: prettyDate(match.updatedAt)
    });
  }

  return synopses;
}

function queryMyMatches(request, response, myTurn) {
  if (!request.user) {
    response.error('user required');
    return;
  }

  var q1 = new Parse.Query("Match");
  q1.containedIn("state", [PENDING,ACTIVE]);
  q1.equalTo("firstPlayer", request.user);
  q1.equalTo("currentPlayerNumber", myTurn ? 0 : 1);

  var q2 = new Parse.Query("Match");
  q2.containedIn("state", [PENDING,ACTIVE]);
  q2.equalTo("secondPlayer", request.user);
  q2.equalTo("currentPlayerNumber", myTurn ? 1 : 0);

  var orQuery = Parse.Query.or(q1, q2);
  orQuery.descending("updatedAt");
  orQuery.include("firstPlayer");
  orQuery.include("secondPlayer");
  orQuery.find({
    success: function (results) {
               response.success(summarizeActivityForMatches(results, request.user));
             },
    error: function () {
             response.error("query failed");
           }
  });
}

Parse.Cloud.define("actionableMatches", function (request, response) {
  queryMyMatches(request, response, true);
});

Parse.Cloud.define("unactionableMatches", function (request, response) {
  queryMyMatches(request, response, false);
});

// The current user is either the first or second player but we don't care whose
// turn it is.

Parse.Cloud.define("activeMatchCount", function (request, response) {
  if (!request.user) {
    response.error('user required');
    return;
  }

  var q1 = new Parse.Query("Match");
  q1.containedIn("state", [PENDING,ACTIVE]);
  q1.equalTo("firstPlayer", request.user);

  var q2 = new Parse.Query("Match");
  q2.containedIn("state", [PENDING,ACTIVE]);
  q2.equalTo("secondPlayer", request.user);

  var orQuery = Parse.Query.or(q1, q2);
  orQuery.count({
    success: function (results) {
               response.success(count1 + count2);
             },
    error: function () {
             response.error("q1 fail");
           }
  });
});

Parse.Cloud.define("completedMatches", function (request, response) {
  if (!request.user) {
    response.error('user required');
    return;
  }

  var q1Results, q2Results;

  var maybeRespond = function () {
    if (q1Results && q2Results) {
      var matches = q1Results.concat(q2Results);
    }
  };

  var q1 = new Parse.Query("Match");
  q1.containedIn("state", [ENDED_NORMAL, ENDED_RESIGN, ENDED_TIMEOUT]);
  q1.equalTo("firstPlayer", request.user);
  q1.include("secondPlayer");
  q1.limit(50);

  var q2 = new Parse.Query("Match");
  q2.containedIn("state", [ENDED_NORMAL, ENDED_RESIGN, ENDED_TIMEOUT]);
  q2.equalTo("secondPlayer", request.user);
  q2.include("firstPlayer");
  q2.limit(50);

  var orQuery = Parse.Query.or(q1, q2);
  orQuery.descending("updatedAt");
  orQuery.find({
    success: function (results) {
               response.success(summarizeActivityForMatches(results, request.user));
             },
    error: function () {
             response.error("query failed");
           }
  });
});

// get count of wins or losses or ties 
// callback(count, error)

function queryRecord(wantWin, wantLose, user, callback) {
  var q1 = new Parse.Query("Match");
  q1.containedIn("state", [ENDED_NORMAL, ENDED_RESIGN, ENDED_TIMEOUT]);

  var q2 = new Parse.Query("Match");
  q2.containedIn("state", [ENDED_NORMAL, ENDED_RESIGN, ENDED_TIMEOUT]);

  if (!wantWin && !wantLose) {        // ties
    q1.equalTo("firstPlayer", user);
    q1.equalTo("winningPlayer", -1);
    q1.equalTo("losingPlayer", -1);
    q2.equalTo("secondPlayer", user);
    q2.equalTo("winningPlayer", -1);
    q2.equalTo("losingPlayer", -1);
  } else if (wantWin && !wantLose) {  // wins
    q1.equalTo("firstPlayer", user);
    q1.equalTo("winningPlayer", 0);
    q2.equalTo("secondPlayer", user);
    q2.equalTo("winningPlayer", 1);
  } else if (!wantWin && wantLose) {  // losses
    q1.equalTo("firstPlayer", user);
    q1.equalTo("losingPlayer", 0);
    q2.equalTo("secondPlayer", user);
    q2.equalTo("losingPlayer", 1);
  }

  var orQuery = Parse.Query.or(q1, q2);
  orQuery.count({
    success: function (results) {
               callback(results);
             },
    error: function () {
             callback(undefined, "query failed");
           }
  });
}

Parse.Cloud.define("getRecord", function (request, response) {
  if (!request.user) {
    response.error('user required');
    return;
  }

  var wins, losses, ties;

  queryRecord(true, false, request.user, function (count, error) {
    if (error) {
      response.error(error);
    } else {
      wins = count;
      queryRecord(false, true, request.user, function (count, error) {
        if (error) {
          response.error(error);
        } else {
          losses = count;
          queryRecord(false, false, request.user, function (count, error) {
            if (error) {
              response.error(error);
            } else {
              ties = count;
              response.success({ w: wins, l: losses, t: ties });
            }
          });
        }
      });
    }
  });
});

