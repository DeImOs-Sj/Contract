// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HealthValidationDAO {
    address public owner;
    uint public maxValidators = 10;
    uint public minValidatorsRequired = 3;
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
        address payable addr;
        bool isActive;
    }

    mapping(address => Validator) public validators;
    ProductValidation[] public validationRequests;

    uint public productStatus; // 0: Not validated, 1: Healthy, 2: Harmful

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
        require(
            !validators[msg.sender].isActive,
            "You are already a validator"
        );
        require(maxValidators > 0, "Validator limit reached");

        validators[msg.sender].addr = payable(msg.sender);
        validators[msg.sender].isActive = true;
        maxValidators--;

        if (msg.value > 0) {
            stakeAmount = msg.value;
        }
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
        string memory _result
    ) external onlyValidator {
        ProductValidation storage request = validationRequests[_requestIndex];
        require(
            request.status == ValidationStatus.Pending,
            "Already validated"
        );

        request.approvals.push(msg.sender);

        if (request.approvals.length >= minValidatorsRequired) {
            uint validVotes = 0;
            uint invalidVotes = 0;

            for (uint i = 0; i < request.approvals.length; i++) {
                if (keccak256(bytes(_result)) == keccak256(bytes("Valid"))) {
                    validVotes++;
                } else if (
                    keccak256(bytes(_result)) == keccak256(bytes("Invalid"))
                ) {
                    invalidVotes++;
                }
            }

            if (validVotes >= minValidatorsRequired) {
                request.status = ValidationStatus.Valid;
                productStatus = 1; // Product is Healthy
            } else if (invalidVotes >= minValidatorsRequired) {
                request.status = ValidationStatus.Invalid;
                productStatus = 2; // Product is Harmful
            }

            if (request.status == ValidationStatus.Valid) {
                payable(request.owner).transfer(rewardAmount);
            }
        }
    }

    function getValidVotes(uint _requestIndex) external view returns (uint) {
        ProductValidation storage request = validationRequests[_requestIndex];
        uint validVotes = 0;
        for (uint i = 0; i < request.approvals.length; i++) {
            address validator = request.approvals[i];
            if (validators[validator].isActive) {
                validVotes++;
            }
        }
        return validVotes;
    }

    function getInvalidVotes(uint _requestIndex) external view returns (uint) {
        ProductValidation storage request = validationRequests[_requestIndex];
        uint invalidVotes = 0;
        for (uint i = 0; i < request.approvals.length; i++) {
            address validator = request.approvals[i];
            if (validators[validator].isActive) {
                invalidVotes++;
            }
        }
        return invalidVotes;
    }

    function contractBalance() external view returns (uint) {
        return address(this).balance;
    }
}
