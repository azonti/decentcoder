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

  Period public period = Period.Announcement;
  event PeriodChanged(Period period);

  modifier onlyDuring(Period p) {
    require(period == p, "Too early or late to call this function");
    _;
  }

  function moveIntoNextPeriod() internal {
    period = Period(uint(period) + 1);
    emit PeriodChanged(period);
  }




  modifier onlyAfter(uint t) {
    require(block.timestamp > t, "Too early to call this function");
    _;
  }

  modifier onlyBefore(uint t) {
    require(block.timestamp <= t, "Too late to call this function");
    _;
  }




  function createContractByCC(bytes memory cc) internal returns (address addr) {
    assembly {
      let ccOffset := add(cc, 0x20)
      let ccLength := mload(cc)
      addr := create(0, ccOffset, ccLength)
    }
  }




  ContestsManager public immutable contestsManager;

  string public name;

  address public immutable organizer;
  uint public immutable organizerDeposit;

  uint public immutable announcementPeriodFinishedAt;
  uint public immutable submissionPeriodFinishedAt;
  uint public immutable claimPeriodFinishedAt;

  uint public constant timedrift = 10 minutes;

  string public encryptedDescriptionCIDPath;
  string public encryptedPresubmissionTesterCCCIDPath;
  string public passphrase;

  mapping(address => uint) public submissionTimestamp;
  mapping(address => bytes32) private submissionCCAddressHash;

  bytes32 private immutable postclaimTesterCCHash;
  bytes private postclaimTesterCC;

  address public winner;
  event WinnerChanged(address winner);

  constructor(
    string memory _name,
    address _organizer,
    uint _organizerDeposit,
    uint _announcementPeriodFinishedAt,
    uint _submissionPeriodFinishedAt,
    uint _claimPeriodFinishedAt,
    string memory _encryptedDescriptionCIDPath,
    string memory _encryptedPresubmissionTesterCCCIDPath,
    bytes32 _postclaimTesterCCHash
  ) payable {
    require(_organizerDeposit <= msg.value, "The organizer's deposit is invalid");

    require(_announcementPeriodFinishedAt + timedrift <= _submissionPeriodFinishedAt, "The submission period is too short");
    require(_submissionPeriodFinishedAt + timedrift <= _claimPeriodFinishedAt, "The claim period is too short");

    contestsManager = ContestsManager(msg.sender);

    name = _name;

    organizer = _organizer;
    organizerDeposit = _organizerDeposit;

    announcementPeriodFinishedAt = _announcementPeriodFinishedAt;
    submissionPeriodFinishedAt = _submissionPeriodFinishedAt;
    claimPeriodFinishedAt = _claimPeriodFinishedAt;

    encryptedDescriptionCIDPath = _encryptedDescriptionCIDPath;
    encryptedPresubmissionTesterCCCIDPath = _encryptedPresubmissionTesterCCCIDPath;

    submissionTimestamp[_organizer] = type(uint).max;

    postclaimTesterCCHash = _postclaimTesterCCHash;

    winner = _organizer;
  }

  function startSubmissionPeriod(
    string memory _passphrase
  )
  external
  onlyBy(organizer)
  onlyDuring(Period.Announcement)
  onlyAfter(announcementPeriodFinishedAt)
  onlyBefore(announcementPeriodFinishedAt + timedrift)
  {
    moveIntoNextPeriod();

    passphrase = _passphrase;
  }

  function submit(
    bytes32 _submissionCCAddressHash
  )
  external
  onlyDuring(Period.Submission)
  onlyBefore(submissionPeriodFinishedAt)
  {
    submissionTimestamp[msg.sender] = block.timestamp;
    submissionCCAddressHash[msg.sender] = _submissionCCAddressHash;
  }

  function startClaimPeriod(
    bytes memory _postclaimTesterCC
  )
  external
  onlyBy(organizer)
  onlyDuring(Period.Submission)
  onlyAfter(submissionPeriodFinishedAt)
  onlyBefore(submissionPeriodFinishedAt + timedrift)
  {
    require(keccak256(_postclaimTesterCC) == postclaimTesterCCHash, "The hashes do not match");

    moveIntoNextPeriod();

    postclaimTesterCC = _postclaimTesterCC;
  }

  function claim(
    bytes memory submissionCC
  )
  external
  onlyDuring(Period.Claim)
  onlyBefore(claimPeriodFinishedAt)
  {
    require(submissionTimestamp[msg.sender] < submissionTimestamp[winner], "You cannot be the winner");
    require(keccak256(abi.encodePacked(submissionCC, msg.sender)) == submissionCCAddressHash[msg.sender], "The hashes do not match");
    require(ITester(createContractByCC(postclaimTesterCC)).test(ISubmission(createContractByCC(submissionCC))), "Your submission is wrong");

    winner = msg.sender;
    emit WinnerChanged(winner);
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
