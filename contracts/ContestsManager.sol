// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./Contest.sol";

contract ContestsManager {
  uint private nContests;
  mapping(Contest => bool) private registered;
  mapping(Contest => Contest) private prevContest;
  mapping(Contest => Contest) private nextContest;
  Contest private tailContest;
  event ContestsChanged();

  function contests() external view returns (Contest[] memory _contests) {
    _contests = new Contest[](nContests);
    Contest contest = nextContest[Contest(0)];
    for (uint i = 0; i < nContests; i++) {
      _contests[i] = contest;
      contest = nextContest[contest];
    }
  }

  function createAndPushNewContest(
    string memory name,
    uint organizerDeposit,
    uint announcementPeriodFinishedAt,
    uint submissionPeriodFinishedAt,
    uint claimPeriodFinishedAt,
    string memory encryptedDescriptionCIDPath,
    string memory encryptedPresubmissionTesterCCCIDPath,
    bytes32 postclaimTesterCCHash
  ) external payable {
    Contest newContest = new Contest{value: msg.value}(
      name,
      msg.sender,
      organizerDeposit,
      announcementPeriodFinishedAt,
      submissionPeriodFinishedAt,
      claimPeriodFinishedAt,
      encryptedDescriptionCIDPath,
      encryptedPresubmissionTesterCCCIDPath,
      postclaimTesterCCHash
    );

    nContests++;
    registered[newContest] = true;
    prevContest[newContest] = tailContest;
    nextContest[tailContest] = newContest;
    tailContest = newContest;

    emit ContestsChanged();
  }

  function removeMe() external {
    require(registered[Contest(msg.sender)], "You have not been registered yet");

    nContests--;
    delete registered[Contest(msg.sender)];
    if (tailContest != Contest(msg.sender)) {
      prevContest[nextContest[Contest(msg.sender)]] = prevContest[Contest(msg.sender)];
      nextContest[prevContest[Contest(msg.sender)]] = nextContest[Contest(msg.sender)];
    } else {
      tailContest = prevContest[Contest(msg.sender)];
    }
    delete prevContest[Contest(msg.sender)];
    delete nextContest[Contest(msg.sender)];

    emit ContestsChanged();
  }
}
