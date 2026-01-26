# Replicate Rate Limit Information

## Current Rate Limit

Your Replicate account currently has a rate limit of **6 images per minute** because the account balance is under $5.

### What This Means

- **Default delay updated:** 10 seconds between images (was 2 seconds)
- **Estimated time:** ~22 minutes for all 130 images (was ~15 minutes)
- **Cost stays the same:** Still $0.39 for 130 images
- **Auto-resume works:** If interrupted, just run again - it skips existing images

## Current Status

The script has automatically adjusted to work within this rate limit. You can:

1. **Continue with current rate limit** (10s delay):
   ```bash
   ./run_image_gen.sh generate
   ```
   Time: ~22 minutes, Cost: $0.39

2. **Add credit to increase rate limit** (see below):
   After adding $5+ credit, use faster generation:
   ```bash
   python3 generate_recipe_images.py --delay 2.0
   ```
   Time: ~15 minutes, Cost: $0.39

## How to Add Credit (Optional)

To increase your rate limit and speed up generation:

1. Go to https://replicate.com/account/billing
2. Add at least $5 in credit
3. Rate limit increases to 100+ requests per minute
4. Generation will be much faster (~15 min instead of ~22 min)

**Note:** You only pay for what you use. Adding $5 credit doesn't mean you'll spend $5 - you'll still only pay $0.39 for the 130 images.

## Resume After Interruption

If generation stops due to rate limiting or other issues:

```bash
./run_image_gen.sh status    # Check progress
./run_image_gen.sh generate  # Resume (skips existing images)
```

The script automatically skips any images that were already generated.

## Check Your Progress

```bash
./run_image_gen.sh status
```

Shows:
- Images generated so far
- Images remaining
- Cost so far
- Estimated remaining cost

## Current Generation Settings

- **Model:** FLUX-dev (high quality)
- **Format:** WebP
- **Size:** 1200×900 (4:3 aspect)
- **Rate limit:** 6 images/minute (with <$5 credit)
- **Delay:** 10 seconds between images
- **Resume:** Automatic (skips existing files)

## Example Timeline

With 6 images/minute rate limit:
- First 10 images: ~2 minutes
- First 30 images: ~5 minutes
- First 60 images: ~10 minutes
- All 130 images: ~22 minutes

## Tips

1. **Let it run:** The script will complete all 130 images, just takes a bit longer
2. **Check status:** Run `./run_image_gen.sh status` anytime in a new terminal
3. **Resume anytime:** If stopped, just run `./run_image_gen.sh generate` again
4. **View progress:** Generated images appear in `images/` directory as they complete

## No Action Needed

The script is already configured to work with your current rate limit. Just run:

```bash
./run_image_gen.sh generate
```

And let it complete (~22 minutes).
