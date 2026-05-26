import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('content_items')
export class ContentItem {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  contentPlanId: string;

  @Column()
  platform: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok';

  @Column()
  contentType: 'post' | 'story' | 'reel' | 'short' | 'carousel';

  @Column()
  title: string;

  @Column('text')
  caption: string;

  @Column('text', { nullable: true })
  imagePrompt: string;

  @Column({ nullable: true })
  imageUrl: string;

  @Column({ nullable: true })
  videoUrl: string;

  @Column('simple-array', { nullable: true })
  hashtags: string[];

  @Column()
  publishAt: Date;

  @Column()
  status: 'draft' | 'needs_review' | 'approved' | 'scheduled' | 'publishing' | 'published' | 'failed';

  @Column()
  approvalStatus: 'pending' | 'approved' | 'rejected';

  @Column({ nullable: true })
  platformPostId: string;

  @Column({ nullable: true })
  errorMessage: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
