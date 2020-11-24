// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./ContestsManager.sol";
import "./ITester.sol";
import "./ISubmission.sol";

contract Contest {
  modifier onlyBy(address a) {
    require(msg.sender == a, "Not authorized to call this function");
    _;
  }




  enum Period {
    Announcement,
    Submission,
    Claim
  }

  Period public period;
  event PeriodChanged(Period period);

  modifier onlyDuring(Period p) {
    require(period == p, "Too early or late to call this function");
    _;
  }




  modifier onlyAfter(uint t) {
    require(block.timestamp > t, "Too early to call this function");
    _;
  }

  modifier onlyBefore(uint t) {
    require(block.timestamp <= t, "Too late to call this function");
    _;
  }




  function getRC(address a) internal returns (bytes memory rc) {
    uint rcSize;
    assembly { rcSize := extcodesize(a) }
    rc = new bytes(rcSize);
    assembly { extcodecopy(a, add(rc, 0x20), 0, rcSize) }
  }

  function isRCPureAndStandalone(bytes memory rc) internal returns (bool) {
    bool code = true;
    for(uint i = 0; i < rc.length; i++) {
      if (code) {
        if (uint8(rc[i]) >= 0x60 && uint8(rc[i]) <= 0x7f) {
          i += uint8(rc[i]) - 0x5f;
        } else if ((uint8(rc[i]) >= 0x30 && uint8(rc[i]) <= 0x33) || (uint8(rc[i]) >= 0x3a && uint8(rc[i]) <= 0x3c) || (uint8(rc[i]) >= 0x3f && uint8(rc[i]) <= 0x45) || uint8(rc[i]) == 0x54 || uint8(rc[i]) == 0x5a) {
          return false;
        } else if (uint8(rc[i]) == 0xf1 || uint8(rc[i]) == 0xf2 || uint8(rc[i]) == 0xf4 || uint8(rc[i]) == 0xfa) {
          return false;
        } else if (uint8(rc[i]) == 0xfe) {
          code = false;
        }
      } else {
        if (uint8(rc[i]) == 0x5b) {
          code = true;
        }
      }
    }
    return true;
  }




  ContestsManager private immutable contestsManager;

  uint public immutable createdBlockNumber;

  address public immutable organizer;

  uint public immutable organizerDeposit;

  uint public immutable announcementPeriodFinishedAt;
  uint public immutable submissionPeriodFinishedAt;
  uint public immutable claimPeriodFinishedAt;

  uint public constant timedrift = 10 minutes;

  bytes32 private immutable passphraseHash;

  bytes32 private immutable postclaimTesterRCHash;

  mapping(address => uint) public submissionTimestamp;

  mapping(address => bytes32) private submissionRCAddressHash;

  ITester private postclaimTester;

  address public winner;
  event WinnerChanged(address winner);

  constructor(
    address _organizer,
    uint _organizerDeposit,
    uint _announcementPeriodFinishedAt,
    uint _submissionPeriodFinishedAt,
    uint _claimPeriodFinishedAt,
    bytes32 _passphraseHash,
    bytes32 _postclaimTesterRCHash
  ) payable {
    require(_organizerDeposit <= msg.value, "The organizer's deposit is invalid");

    require(_announcementPeriodFinishedAt + timedrift <= _submissionPeriodFinishedAt, "The submission period is too short");
    require(_submissionPeriodFinishedAt + timedrift <= _claimPeriodFinishedAt, "The claim period is too short");

    period = Period.Announcement;
    emit PeriodChanged(Period.Announcement);

    contestsManager = ContestsManager(msg.sender);

    createdBlockNumber = block.number;

    organizer = _organizer;

    organizerDeposit = _organizerDeposit;

    announcementPeriodFinishedAt = _announcementPeriodFinishedAt;
    submissionPeriodFinishedAt = _submissionPeriodFinishedAt;
    claimPeriodFinishedAt = _claimPeriodFinishedAt;

    passphraseHash = _passphraseHash;

    postclaimTesterRCHash = _postclaimTesterRCHash;

    submissionTimestamp[_organizer] = type(uint).max;

    winner = _organizer;
    emit WinnerChanged(_organizer);
  }

  function startSubmissionPeriod(
    string memory passphrase
  )
  external
  onlyBy(organizer)
  onlyDuring(Period.Announcement)
  onlyAfter(announcementPeriodFinishedAt)
  onlyBefore(announcementPeriodFinishedAt + timedrift)
  {
    require(keccak256(abi.encodePacked(passphrase)) == passphraseHash, "The hashes do not match");

    period = Period.Submission;
    emit PeriodChanged(Period.Submission);
  }

  function submit(
    bytes32 _submissionRCAddressHash
  )
  external
  onlyDuring(Period.Submission)
  onlyBefore(submissionPeriodFinishedAt)
  {
    submissionTimestamp[msg.sender] = block.timestamp;

    submissionRCAddressHash[msg.sender] = _submissionRCAddressHash;
  }

  function startClaimPeriod(
    ITester _postclaimTester
  )
  external
  onlyBy(organizer)
  onlyDuring(Period.Submission)
  onlyAfter(submissionPeriodFinishedAt)
  onlyBefore(submissionPeriodFinishedAt + timedrift)
  {
    bytes memory postclaimTesterRC = getRC(address(_postclaimTester));
    require(keccak256(postclaimTesterRC) == postclaimTesterRCHash, "The hashes do not match");
    require(isRCPureAndStandalone(postclaimTesterRC), "The postclaim tester is non-pure or non-standalone");

    period = Period.Claim;
    emit PeriodChanged(Period.Claim);

    postclaimTester = _postclaimTester;
  }

  function claim(
    ISubmission submission
  )
  external
  onlyDuring(Period.Claim)
  onlyBefore(claimPeriodFinishedAt)
  {
    require(submissionTimestamp[msg.sender] < submissionTimestamp[winner], "You cannot be the winner");

    bytes memory submissionRC = getRC(address(submission));
    require(keccak256(abi.encodePacked(submissionRC, msg.sender)) == submissionRCAddressHash[msg.sender], "The hashes do not match");
    require(isRCPureAndStandalone(submissionRC), "The submission is non-pure or non-standalone");

    require(postclaimTester.isOutput1Correct(submission.main(postclaimTester.input1())), "Your submission is wrong");
    require(postclaimTester.isOutput2Correct(submission.main(postclaimTester.input2())), "Your submission is wrong");
    require(postclaimTester.isOutput3Correct(submission.main(postclaimTester.input3())), "Your submission is wrong");

    winner = msg.sender;
    emit WinnerChanged(msg.sender);
  }

  function terminateNormally()
  external
  onlyDuring(Period.Claim)
  onlyAfter(claimPeriodFinishedAt)
  {
    contestsManager.removeMe();

    payable(organizer).transfer(organizerDeposit);

    selfdestruct(payable(winner));
  }

  function terminateAbnormally()
  external
  {
    require(
      (
        block.timestamp > announcementPeriodFinishedAt + timedrift &&
        period == Period.Announcement
      ) || (
        block.timestamp > submissionPeriodFinishedAt + timedrift &&
        period == Period.Submission
      ),
      "The organizer is honest"
    );

    contestsManager.removeMe();

    msg.sender.transfer(organizerDeposit);

    selfdestruct(payable(winner));
  }

  receive() external payable {}
}
