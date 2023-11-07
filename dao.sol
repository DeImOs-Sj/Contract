// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HealthValidationDAO {
    address public owner;
    uint public maxValidators = 10;
    uint public minValidatorsRequired = 5;
    uint public stakeAmount = 0.001 ether;
    uint public rewardAmount = 0.1 ether;

    enum ValidationStatus {
        Pending,
        Valid,
        Invalid
    }

    struct ProductValidation {
        address owner;
        string product;
        ValidationStatus status;
        address[] approvals;
    }

    struct Validator {
        address payable addr; // Mark as payable
        bool isActive;
    }

    mapping(address => Validator) public validators;
    ProductValidation[] public validationRequests;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyValidator() {
        require(
            validators[msg.sender].isActive,
            "Only validators can perform this action"
        );
        _;
    }

    function addValidator() external payable {
        require(msg.value >= stakeAmount, "Stake amount insufficient");
        require(
            !validators[msg.sender].isActive,
            "You are already a validator"
        );
        require(maxValidators > 0, "Validator limit reached");

        validators[msg.sender].addr = payable(msg.sender);
        validators[msg.sender].isActive = true;
        maxValidators--;
    }

    function submitValidationRequest(string memory _product) external {
        ProductValidation memory request;
        request.owner = msg.sender;
        request.product = _product;
        request.status = ValidationStatus.Pending;
        validationRequests.push(request);
    }

    function validateProduct(
        uint _requestIndex,
        ValidationStatus _status
    ) external onlyValidator {
        ProductValidation storage request = validationRequests[_requestIndex];
        require(
            request.status == ValidationStatus.Pending,
            "Already validated"
        );

        request.approvals.push(msg.sender);
        request.status = _status;

        if (request.approvals.length >= minValidatorsRequired) {
            if (_status == ValidationStatus.Valid) {
                // Reward the submitter
                payable(request.owner).transfer(rewardAmount);

                // Distribute validator stakes and rewards
                distributeValidatorRewards(request.approvals);
            } else {
                // Penalize the validator
                validators[msg.sender].isActive = false;
            }
        }
    }

    function distributeValidatorRewards(address[] memory _approvals) internal {
        uint totalStake = stakeAmount * _approvals.length;
        uint individualReward = rewardAmount / _approvals.length;

        for (uint i = 0; i < _approvals.length; i++) {
            validators[_approvals[i]].addr.transfer(
                individualReward + stakeAmount
            );
        }

        payable(owner).transfer(totalStake - rewardAmount);
    }

    function contractBalance() external view returns (uint) {
        return address(this).balance;
    }
}
