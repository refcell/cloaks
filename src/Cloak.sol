// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

/// @notice Extensible ERC721 Implementation with a Built-in Commit-Reveal Scheme.
/// @author andreas <andreas@nascent.xyz>
abstract contract Cloak {
    ////////////////////////////////////////////////////
    ///                 CUSTOM ERRORS                ///
    ////////////////////////////////////////////////////

    error NotAuthorized();

    error WrongFrom();

    error InvalidRecipient();

    error UnsafeRecipient();

    error AlreadyMinted();

    error NotMinted();

    error InsufficientDeposit();

    error WrongPhase();

    error InvalidHash();

    error InsufficientPrice();

    error InsufficientValue();

    error InvalidAction();

    ////////////////////////////////////////////////////
    ///                    EVENTS                    ///
    ////////////////////////////////////////////////////

    event Commit(address indexed from);

    event Reveal(address indexed from, uint256 appraisal);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    ////////////////////////////////////////////////////
    ///                   METADATA                   ///
    ////////////////////////////////////////////////////

    string public name;

    string public symbol;

    function tokenURI(uint256 id) public view virtual returns (string memory);

    ////////////////////////////////////////////////////
    ///                  IMMUTABLES                  ///
    ////////////////////////////////////////////////////

    /// @dev The deposit amount to place a commitment
    uint256 public immutable depositAmount;

    /// @dev The minimum mint price
    uint256 public immutable minPrice;

    /// @dev Commit Start Timestamp
    uint256 public immutable commitStart;

    /// @dev Reveal Start Timestamp
    uint256 public immutable revealStart;

    /// @dev Mint Start Timestamp
    uint256 public immutable mintStart;

    /// @dev Optional ERC20 Deposit Token
    address public depositToken;

    /// @dev Flex is a scaling factor for standard deviation in price band calculation
    uint256 public flex;

    ////////////////////////////////////////////////////
    ///               CUSTOM STORAGE                 ///
    ////////////////////////////////////////////////////

    /// @dev The outlier scale for loss penalty
    /// @dev Loss penalty is taken with OUTLIER_FLEX * error as a percent
    uint256 public constant OUTLIER_FLEX = 5;

    /// @dev A rolling variance calculation
    /// @dev Used for minting price bands
    uint256 public rollingVariance;

    /// @dev The number of commits calculated
    uint256 public count;

    /// @dev The result cumulative sum
    uint256 public resultPrice;

    /// @dev The total token supply
    uint256 public totalSupply;

    /// @dev User Commitments
    mapping(address => bytes32) public commits;

    /// @dev The resulting user appraisals
    mapping(address => uint256) public reveals;

    ////////////////////////////////////////////////////
    ///                ERC721 STORAGE                ///
    ////////////////////////////////////////////////////

    mapping(address => uint256) public balanceOf;

    mapping(uint256 => address) public ownerOf;

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    ////////////////////////////////////////////////////
    ///                 CONSTRUCTOR                  ///
    ////////////////////////////////////////////////////

    constructor(
      string memory _name,
      string memory _symbol,
      uint256 _depositAmount,
      uint256 _minPrice,
      uint256 _commitStart,
      uint256 _revealStart,
      uint256 _mintStart,
      address _depositToken,
      uint256 _flex
    ) {
        name = _name;
        symbol = _symbol;

        // Store immutables
        depositAmount = _depositAmount;
        minPrice = _minPrice;
        commitStart = _commitStart;
        revealStart = _revealStart;
        mintStart = _mintStart;
        depositToken = _depositToken;
        flex = _flex;
    }

    ////////////////////////////////////////////////////
    ///              COMMIT-REVEAL LOGIC             ///
    ////////////////////////////////////////////////////

    /// @notice Commit is payable to require the deposit amount
    function commit(bytes32 commitment) external payable {
        // Make sure the user has placed the deposit amount
        if (depositToken == address(0) && msg.value < depositAmount) revert InsufficientDeposit();
        
        // Verify during commit phase
        if (block.timestamp < commitStart || block.timestamp >= revealStart) revert WrongPhase();
        
        // Transfer the deposit token into this contract
        if (depositToken != address(0)) {
          IERC20(depositToken).transferFrom(msg.sender, address(this), depositAmount);
        }

        // Update a user's commitment if one's outstanding
        // if (commits[msg.sender] != bytes32(0)) count += 1;
        commits[msg.sender] = commitment;

        // Emit the commit event
        emit Commit(msg.sender);
    }

    /// @notice Revealing a commitment
    function reveal(uint256 appraisal, bytes32 blindingFactor) external {
        // Verify during reveal+mint phase
        if (block.timestamp < revealStart || block.timestamp >= mintStart) revert WrongPhase();

        bytes32 senderCommit = commits[msg.sender];

        bytes32 calculatedCommit = keccak256(abi.encodePacked(msg.sender, appraisal, blindingFactor));

        if (senderCommit != calculatedCommit) revert InvalidHash();

        // The user has revealed their correct value
        delete commits[msg.sender];
        reveals[msg.sender] = appraisal;

        // Add the appraisal to the result value and recalculate variance
        // Calculation adapted from https://math.stackexchange.com/questions/102978/incremental-computation-of-standard-deviation
        if (count == 0) {
          resultPrice = appraisal;
        } else {
          // we have two or more values now so we calculate variance
          uint256 carryTerm = ((count - 1) * rollingVariance) / count;
          uint256 diff = appraisal < resultPrice ? resultPrice - appraisal : appraisal - resultPrice;
          uint256 updateTerm = (diff ** 2) / (count + 1);
          rollingVariance = carryTerm + updateTerm;
          // Update resultPrice (new mean)
          resultPrice = (count * resultPrice + appraisal) / (count + 1);
        }
        count += 1;

        // Emit a Reveal Event
        emit Reveal(msg.sender, appraisal);
    }

    ////////////////////////////////////////////////////
    ///                  MINT LOGIC                  ///
    ////////////////////////////////////////////////////

    /// @notice Enables Minting During the Minting Phase
    function mint() external payable {
        // Verify during mint phase
        if (block.timestamp < mintStart) revert WrongPhase();

        // Sload the user's appraisal value
        uint256 senderAppraisal = reveals[msg.sender];

        // Result value
        uint256 finalValue = resultPrice;
        if (resultPrice < minPrice) finalValue = minPrice;

        // Verify they sent at least enough to cover the mint cost
        if (depositToken == address(0) && msg.value < finalValue) revert InsufficientValue();
        if (depositToken != address(0)) IERC20(depositToken).transferFrom(msg.sender, address(this), finalValue);

        // Use Reveals as a mask
        if (reveals[msg.sender] == 0) revert InvalidAction(); 

        // Check that the appraisal is within the price band
        uint256 stdDev = FixedPointMathLib.sqrt(rollingVariance);
        if (senderAppraisal < (resultPrice - flex * stdDev) || senderAppraisal > (resultPrice + flex * stdDev)) {
          revert InsufficientPrice();
        }

        // Delete revealed value to prevent double spend
        delete reveals[msg.sender];

        // Send deposit back to the minter
        if(depositToken == address(0)) msg.sender.call{value: depositAmount}("");
        else IERC20(depositToken).transfer(msg.sender, depositAmount);

        // Otherwise, we can mint the token
        _mint(msg.sender, totalSupply);
        totalSupply += 1;
    }

    /// @notice Forgos a mint
    /// @notice A penalty is assumed if the user's sealed bid was within the minting threshold
    function forgo() external {
        // Verify during mint phase
        if (block.timestamp < mintStart) revert WrongPhase();

        // Use Reveals as a mask
        if (reveals[msg.sender] == 0) revert InvalidAction(); 
        
        // Sload the user's appraisal value
        uint256 senderAppraisal = reveals[msg.sender];

        // Calculate a Loss penalty
        uint256 lossPenalty = 0;
        uint256 stdDev = FixedPointMathLib.sqrt(rollingVariance);
        uint256 diff = senderAppraisal < resultPrice ? resultPrice - senderAppraisal : senderAppraisal - resultPrice;
        if (stdDev != 0 && senderAppraisal >= (resultPrice - flex * stdDev) && senderAppraisal <= (resultPrice + flex * stdDev)) {
          lossPenalty = ((diff / stdDev) * depositAmount) / 100;
        }

        // Increase loss penalty if it's an outlier using Z-scores
        if (stdDev != 0) {
          // Take a penalty of OUTLIER_FLEX * error as a percent
          lossPenalty += OUTLIER_FLEX * (diff / stdDev) * depositAmount / 100;
        }

        // Return the deposit less the loss penalty
        // NOTE: we can let this error on underflow since that means Cloak should keep the full deposit
        uint256 amountTransfer = depositAmount - lossPenalty;

        // Transfer eth or erc20 back to user
        delete reveals[msg.sender];
        if(depositToken == address(0)) msg.sender.call{value: amountTransfer}("");
        else IERC20(depositToken).transfer(msg.sender, amountTransfer);
    }

    /// @notice Allows a user to withdraw their deposit on reveal elusion
    function lostReveal() external {
        // Verify after the reveal phase
        if (block.timestamp < mintStart) revert WrongPhase();

        // Prevent withdrawals unless reveals is empty and commits isn't
        if (reveals[msg.sender] != 0 || commits[msg.sender] == 0) revert InvalidAction();
    
        // Then we can release deposit
        delete commits[msg.sender];
        if(depositToken == address(0)) msg.sender.call{value: depositAmount}("");
        else IERC20(depositToken).transfer(msg.sender, depositAmount);
    }

    /// @notice Allows a user to view if they can mint
    function canMint() external view returns (bool mintable) {
      // Sload the user's appraisal value
      uint256 senderAppraisal = reveals[msg.sender];
      uint256 stdDev = FixedPointMathLib.sqrt(rollingVariance);
      mintable = senderAppraisal >= (resultPrice - flex * stdDev) && senderAppraisal <= (resultPrice + flex * stdDev);
    }

    ////////////////////////////////////////////////////
    ///                 ERC721 LOGIC                 ///
    ////////////////////////////////////////////////////

    function approve(address spender, uint256 id) public virtual {
        address owner = ownerOf[id];

        if (msg.sender != owner || !isApprovedForAll[owner][msg.sender]) {
          revert NotAuthorized();
        }

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        if (from != ownerOf[id]) revert WrongFrom();

        if (to == address(0)) revert InvalidRecipient();

        if (msg.sender != from || msg.sender != getApproved[id] || !isApprovedForAll[from][msg.sender]) {
          revert NotAuthorized();
        }

        // Underflow impossible due to check for ownership
        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }

        ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        if (
          to.code.length != 0 ||
          ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") !=
          ERC721TokenReceiver.onERC721Received.selector
        ) {
          revert UnsafeRecipient();
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public virtual {
        transferFrom(from, to, id);

        if (
          to.code.length != 0 ||
          ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) !=
          ERC721TokenReceiver.onERC721Received.selector
        ) {
          revert UnsafeRecipient();
        }
    }

    ////////////////////////////////////////////////////
    ///                 ERC165 LOGIC                 ///
    ////////////////////////////////////////////////////

    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata
    }

    ////////////////////////////////////////////////////
    ///                INTERNAL LOGIC                ///
    ////////////////////////////////////////////////////

    function _mint(address to, uint256 id) internal virtual {
        if (to == address(0)) revert InvalidRecipient();

        if (ownerOf[id] != address(0)) revert AlreadyMinted();

        // Counter overflow is incredibly unrealistic.
        unchecked {
            balanceOf[to]++;
        }

        ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = ownerOf[id];

        if (ownerOf[id] == address(0)) revert NotMinted();

        // Ownership check above ensures no underflow.
        unchecked {
            balanceOf[owner]--;
        }

        delete ownerOf[id];

        delete getApproved[id];

        emit Transfer(owner, address(0), id);
    }

    ////////////////////////////////////////////////////
    ///             INTERNAL SAFE LOGIC              ///
    ////////////////////////////////////////////////////

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        if (
          to.code.length != 0 ||
          ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") !=
          ERC721TokenReceiver.onERC721Received.selector
        ) {
          revert UnsafeRecipient();
        }
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        if (
          to.code.length != 0 ||
          ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) !=
          ERC721TokenReceiver.onERC721Received.selector
        ) {
          revert UnsafeRecipient();
        }
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4);
}
