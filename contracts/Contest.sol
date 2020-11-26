// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "./ContestsManager.sol";
import "./ITester.sol";
import "./IAnswer.sol";

contract Contest {
  modifier onlyBy(address a) {
    require(msg.sender == a, "Not authorized to call this function");
    _;
  }




  enum Phase {
    Announcement,
    Submission,
    Claim
  }

  Phase public phase;
  event PhaseChanged(Phase phase);

  modifier onlyDuring(Phase p) {
    require(phase == p, "Too early or late to call this function");
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

  function getRCHash(address a) internal returns (bytes32) {
    bytes32 rcHash;
    assembly { rcHash := extcodehash(a) }
    return rcHash;
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

  uint public immutable announcementPhaseFinishedAt;
  uint public immutable submissionPhaseFinishedAt;
  uint public immutable claimPhaseFinishedAt;

  uint public constant timedrift = 10 minutes;

  bytes32 private immutable passphraseHash;

  bytes32 private immutable postclaimTesterRCHash;

  mapping(address => uint) public submissionTimestamp;

  mapping(address => bytes32) private answerRCHashAddressHash;

  ITester private postclaimTester;

  address public winner;
  event WinnerChanged(address winner);

  constructor(
    address _organizer,
    uint _organizerDeposit,
    uint _announcementPhaseFinishedAt,
    uint _submissionPhaseFinishedAt,
    uint _claimPhaseFinishedAt,
    bytes32 _passphraseHash,
    bytes32 _postclaimTesterRCHash
  ) payable {
    require(_organizerDeposit <= msg.value, "The organizer's deposit is invalid");

    require(_announcementPhaseFinishedAt + timedrift <= _submissionPhaseFinishedAt, "The submission phase is too short");
    require(_submissionPhaseFinishedAt + timedrift <= _claimPhaseFinishedAt, "The claim phase is too short");

    phase = Phase.Announcement;
    emit PhaseChanged(Phase.Announcement);

    contestsManager = ContestsManager(msg.sender);

    createdBlockNumber = block.number;

    organizer = _organizer;

    organizerDeposit = _organizerDeposit;

    announcementPhaseFinishedAt = _announcementPhaseFinishedAt;
    submissionPhaseFinishedAt = _submissionPhaseFinishedAt;
    claimPhaseFinishedAt = _claimPhaseFinishedAt;

    passphraseHash = _passphraseHash;

    postclaimTesterRCHash = _postclaimTesterRCHash;

    submissionTimestamp[_organizer] = type(uint).max;

    winner = _organizer;
    emit WinnerChanged(_organizer);
  }

  function startSubmissionPhase(
    string memory passphrase
  )
  external
  onlyBy(organizer)
  onlyDuring(Phase.Announcement)
  onlyAfter(announcementPhaseFinishedAt)
  onlyBefore(announcementPhaseFinishedAt + timedrift)
  {
    require(keccak256(abi.encodePacked(passphrase)) == passphraseHash, "The hashes do not match");

    phase = Phase.Submission;
    emit PhaseChanged(Phase.Submission);
  }

  function submit(
    bytes32 _answerRCHashAddressHash
  )
  external
  onlyDuring(Phase.Submission)
  onlyBefore(submissionPhaseFinishedAt)
  {
    submissionTimestamp[msg.sender] = block.timestamp;

    answerRCHashAddressHash[msg.sender] = _answerRCHashAddressHash;
  }

  function startClaimPhase(
    ITester _postclaimTester
  )
  external
  onlyBy(organizer)
  onlyDuring(Phase.Submission)
  onlyAfter(submissionPhaseFinishedAt)
  onlyBefore(submissionPhaseFinishedAt + timedrift)
  {
    bytes32 _postclaimTesterRCHash = getRCHash(address(_postclaimTester));
    require(_postclaimTesterRCHash == postclaimTesterRCHash, "The hashes do not match");
    bytes memory _postclaimTesterRC = getRC(address(_postclaimTester));
    require(isRCPureAndStandalone(_postclaimTesterRC), "The postclaim tester is non-pure or non-standalone");

    phase = Phase.Claim;
    emit PhaseChanged(Phase.Claim);

    postclaimTester = _postclaimTester;
  }

  function claim(
    IAnswer answer
  )
  external
  onlyDuring(Phase.Claim)
  onlyBefore(claimPhaseFinishedAt)
  {
    require(submissionTimestamp[msg.sender] < submissionTimestamp[winner], "You cannot be the winner");

    bytes32 answerRCHash = getRCHash(address(answer));
    require(keccak256(abi.encodePacked(answerRCHash, msg.sender)) == answerRCHashAddressHash[msg.sender], "The hashes do not match");
    bytes memory answerRC = getRC(address(answer));
    require(isRCPureAndStandalone(answerRC), "The answer is non-pure or non-standalone");

    require(postclaimTester.isOutput1Correct(answer.answer(postclaimTester.input1())), "Your answer is wrong");
    require(postclaimTester.isOutput2Correct(answer.answer(postclaimTester.input2())), "Your answer is wrong");
    require(postclaimTester.isOutput3Correct(answer.answer(postclaimTester.input3())), "Your answer is wrong");

    winner = msg.sender;
    emit WinnerChanged(msg.sender);
  }

  function terminateNormally()
  external
  onlyDuring(Phase.Claim)
  onlyAfter(claimPhaseFinishedAt)
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
        block.timestamp > announcementPhaseFinishedAt + timedrift &&
        phase == Phase.Announcement
      ) || (
        block.timestamp > submissionPhaseFinishedAt + timedrift &&
        phase == Phase.Submission
      ),
      "The organizer is honest"
    );

    contestsManager.removeMe();

    msg.sender.transfer(organizerDeposit);

    selfdestruct(payable(winner));
  }

  receive() external payable {}
}
