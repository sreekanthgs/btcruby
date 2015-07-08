module BTC
  class MerkleTree
    
    attr_reader :merkle_root
    
    def initialize(hashes: nil, transactions: nil, items: nil)
      raise ArgumentError, "None of the arguments are used" if !transactions && !hashes && !items
      if transactions
        hashes = transactions.map{|tx| tx.transaction_hash}
      elsif items
        hashes = items.map{|item| BTC.hash256(item) }
      end
      raise ArgumentError, "Empty list is not allowed" if hashes.size == 0
      @hashes = hashes
    end
    
    def merkle_root
      @merkle_root ||= compute_merkle_root
    end
    
    def tail_duplicates?
      if !@merkle_root
        @merkle_root = compute_merkle_root
      end
      @tail_duplicates
    end
    
    private
    
    def compute_merkle_root
      # Based on original Satoshi implementation + vulnerability detection API:
      # WARNING! If you're reading this because you're learning about crypto
      # and/or designing a new system that will use merkle trees, keep in mind
      # that the following merkle tree algorithm has a serious flaw related to
      # duplicate txids, resulting in a vulnerability (CVE-2012-2459).
      # 
      # The reason is that if the number of hashes in the list at a given time
      # is odd, the last one is duplicated before computing the next level (which
      # is unusual in Merkle trees). This results in certain sequences of
      # transactions leading to the same merkle root. For example, these two
      # trees:
      # 
      #              A               A
      #            /  \            /   \
      #          B     C         B       C
      #         / \    |        / \     / \
      #        D   E   F       D   E   F   F
      #       / \ / \ / \     / \ / \ / \ / \
      #       1 2 3 4 5 6     1 2 3 4 5 6 5 6
      # 
      # for transaction lists [1,2,3,4,5,6] and [1,2,3,4,5,6,5,6] (where 5 and
      # 6 are repeated) result in the same root hash A (because the hash of both
      # of (F) and (F,F) is C).
      # 
      # The vulnerability results from being able to send a block with such a
      # transaction list, with the same merkle root, and the same block hash as
      # the original without duplication, resulting in failed validation. If the
      # receiving node proceeds to mark that block as permanently invalid
      # however, it will fail to accept further unmodified (and thus potentially
      # valid) versions of the same block. We defend against this by detecting
      # the case where we would hash two identical hashes at the end of the list
      # together, and treating that identically to the block having an invalid
      # merkle root. Assuming no double-SHA256 collisions, this will detect all
      # known ways of changing the transactions without affecting the merkle
      # root.
      
      @tail_duplicates = false

      tree = @hashes.dup
      j = 0
      size = tree.size
      while size > 1
        i = 0
        while i < size
          i2 = [i + 1, size - 1].min
          if i2 == i + 1 && i2 + 1 == size && tree[j+i] == tree[j+i2]
            # Two identical hashes at the end of the list at a particular level.
            @tail_duplicates = true
          end
          hash = BTC.hash256(tree[j+i] + tree[j+i2])
          tree << hash
          i += 2
        end
        j += size
        size = (size + 1) / 2
      end
      tree.last
    end
    
  end # MerkleTree
end # BTC
