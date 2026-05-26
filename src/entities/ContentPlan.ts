import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('content_plans')
export class ContentPlan {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  socialAccountId: string;

  @Column()
  title: string;

  @Column()
  periodStart: Date;

  @Column()
  periodEnd: Date;

  @Column()
  status: 'draft' | 'active' | 'completed';

  @Column()
  createdByAgentId: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
